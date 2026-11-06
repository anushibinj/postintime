import { rmSync } from 'node:fs';
import { join } from 'node:path';
import qrcode from 'qrcode-terminal';
import whatsappWeb from 'whatsapp-web.js';

const { Client, LocalAuth } = whatsappWeb;

/**
 * Starts whatsapp-web.js, prints the login QR code in the terminal when there is no saved
 * session, and resolves with the logged-in client once WhatsApp is ready.
 */
export function startWhatsAppClient({
  sessionDir,
  headless,
  puppeteerExecutablePath,
  readyTimeoutSeconds = 300,
  logger = console,
}) {
  removeStaleChromeLocks(sessionDir);
  const client = new Client({
    authStrategy: new LocalAuth({ dataPath: sessionDir }),
    puppeteer: {
      headless,
      executablePath: puppeteerExecutablePath,
      // Needed when Chrome runs as root or in a container (Docker's /dev/shm is only 64 MB).
      args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage'],
    },
  });

  client.on('qr', (qr) => {
    logger.log('\nScan this QR code with WhatsApp (Settings > Linked devices > Link a device):\n');
    qrcode.generate(qr, { small: true });
  });

  const ready = waitForReady(client, { timeoutMs: readyTimeoutSeconds * 1000, logger });
  client.initialize().catch((error) => client.emit('init_failure', error));
  return ready.catch(async (error) => {
    await client.destroy().catch(() => {});
    throw error;
  });
}

/**
 * Resolves with the client when it fires 'ready'. Rejects when the login fails, when initialize() fails, or
 * when WhatsApp has not finished loading chats `timeoutMs` after the login was accepted.
 *
 * whatsapp-web.js loads chats inside the browser page; when that fails (often after a WhatsApp Web update)
 * the error stays in the page and 'ready' never comes. So log what the page reports, and give up in time.
 */
export function waitForReady(client, { timeoutMs, logger = console }) {
  return new Promise((resolve, reject) => {
    let timer;
    let lastPercent;
    let settled = false;
    const finish = (callback, value) => {
      settled = true;
      clearTimeout(timer);
      callback(value);
    };

    // whatsapp-web.js can fire 'authenticated' several times while it loads; act on the first.
    client.once('authenticated', () => {
      logger.log('WhatsApp login accepted, loading chats…');
      watchPageErrors(client.pupPage, logger, () => !settled);
      timer = setTimeout(() => {
        settled = true;
        reject(
          new Error(
            `WhatsApp did not finish loading chats within ${Math.round(timeoutMs / 1000)} seconds. ` +
              'Restart the client; if it keeps happening, update whatsapp-web.js or log in again ' +
              '(delete the saved session and scan the QR code).',
          ),
        );
      }, timeoutMs);
    });
    client.on('loading_screen', (percent) => {
      if (percent !== lastPercent) {
        lastPercent = percent;
        logger.log(`Loading WhatsApp: ${percent}%`);
      }
    });
    client.on('change_state', (state) => logger.log(`WhatsApp state: ${state}`));
    client.on('auth_failure', (message) => finish(reject, new Error(`WhatsApp login failed: ${message}`)));
    client.on('init_failure', (error) => finish(reject, error instanceof Error ? error : new Error(String(error))));
    client.on('disconnected', (reason) => logger.error(`WhatsApp disconnected: ${reason}`));
    client.once('ready', () => finish(resolve, client));
  });
}

/**
 * Logs errors thrown inside the WhatsApp Web page while chats load, which whatsapp-web.js would otherwise
 * hide. Stops once loading is over, as WhatsApp Web logs plenty of harmless errors later on.
 */
function watchPageErrors(page, logger, isLoading) {
  if (!page || typeof page.on !== 'function') {
    return;
  }
  page.on('pageerror', (error) => {
    if (isLoading()) {
      logger.error(`WhatsApp Web page error: ${error?.message ?? error}`);
    }
  });
  page.on('console', (message) => {
    if (isLoading() && message.type() === 'error') {
      logger.error(`WhatsApp Web console error: ${message.text()}`);
    }
  });
}

/**
 * Chrome leaves lock files in its profile when it is killed (for example when a container stops).
 * The next start then fails with "The browser is already running". Only one client uses this
 * session folder, so the locks are always stale here.
 */
export function removeStaleChromeLocks(sessionDir) {
  // LocalAuth keeps the Chrome profile in <dataPath>/session.
  for (const name of ['SingletonLock', 'SingletonSocket', 'SingletonCookie']) {
    rmSync(join(sessionDir, 'session', name), { force: true });
  }
}

/**
 * Finds the id of the default channel from WHATSAPP_CHANNEL_ID or WHATSAPP_CHANNEL_INVITE_CODE,
 * or returns undefined when neither is set.
 *
 * An invite code is first matched against the channels WhatsApp Web has loaded. Only then is
 * client.getChannelByInviteCode() tried: it relies on WhatsApp Web internals that change (in
 * whatsapp-web.js 1.34.7 it fails with "getRoleByIdentifier is not a function").
 */
export async function resolveChannelId(client, { channelId, channelInviteCode }, { listChannelsFn = listChannels } = {}) {
  if (channelId) {
    return channelId;
  }
  if (!channelInviteCode) {
    return undefined;
  }
  const inviteCode = inviteCodeFrom(channelInviteCode);

  const loaded = (await listChannelsFn(client).catch(() => [])).find((channel) => channel.inviteCode === inviteCode);
  if (loaded) {
    return loaded.id;
  }

  let channel;
  try {
    channel = await client.getChannelByInviteCode(inviteCode);
  } catch (error) {
    throw new Error(
      `Could not look up the channel for invite code "${channelInviteCode}" (${error?.message ?? error}). ` +
        'Set WHATSAPP_CHANNEL_ID to one of the ids listed under "Channels on this WhatsApp account" instead.',
    );
  }
  if (!channel) {
    throw new Error(`No WhatsApp channel found for invite code "${channelInviteCode}".`);
  }
  return channel.id._serialized;
}

/** Accepts either the bare invite code or the full https://whatsapp.com/channel/<code> link. */
export function inviteCodeFrom(value) {
  const match = value.match(/whatsapp\.com\/channel\/([^/?#\s]+)/i);
  return match ? match[1] : value;
}

/**
 * Reads the id and name of each channel WhatsApp Web has loaded. client.getChannels() also refreshes every
 * channel's metadata through WhatsApp Web internals, which can throw; listing needs none of that.
 */
export async function listChannels(client) {
  return client.pupPage.evaluate(() => {
    const collections = window.require('WAWebCollections');
    const newsletters = collections.WAWebNewsletterCollection ?? collections.Newsletter;
    return (newsletters?.getModelsArray() ?? []).map((channel) => {
      const metadata = channel.newsletterMetadata ?? {};
      const inviteLink = channel.inviteLink ?? metadata.inviteLink ?? '';
      return {
        id: channel.id?._serialized,
        name: channel.name ?? metadata.name ?? '',
        // Only known for channels whose metadata WhatsApp Web has already loaded.
        inviteCode: channel.inviteCode ?? metadata.inviteCode ?? inviteLink.split('/').pop() ?? undefined,
      };
    });
  });
}

/**
 * Prints the channels this account follows or owns, to help fill in the webhook URL.
 *
 * WhatsApp Web loads channels a few seconds after the client is ready, so keep asking for a while before
 * deciding there are none.
 */
export async function logChannels(client, { logger = console, attempts = 20, intervalMs = 3000 } = {}) {
  try {
    let channels = [];
    for (let attempt = 1; attempt <= attempts; attempt++) {
      channels = await listChannels(client);
      if (channels.length > 0 || attempt === attempts) {
        break;
      }
      await new Promise((resolve) => setTimeout(resolve, intervalMs));
    }
    if (channels.length === 0) {
      logger.log(
        'No WhatsApp channels found on this account yet. Open the channel once in WhatsApp on your phone, ' +
          'or set WHATSAPP_CHANNEL_INVITE_CODE to the channel link to look its id up.',
      );
      return;
    }
    logger.log('Channels on this WhatsApp account:');
    for (const channel of channels) {
      logger.log(`  ${channel.id}  ${channel.name}`);
    }
  } catch (error) {
    logger.error('Could not list WhatsApp channels:', error?.stack ?? error?.message ?? error);
  }
}
