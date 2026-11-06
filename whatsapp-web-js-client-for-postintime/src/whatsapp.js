import { rmSync } from 'node:fs';
import { join } from 'node:path';
import qrcode from 'qrcode-terminal';
import whatsappWeb from 'whatsapp-web.js';

const { Client, LocalAuth } = whatsappWeb;

/**
 * Starts whatsapp-web.js, prints the login QR code in the terminal when there is no saved
 * session, and resolves with the logged-in client once WhatsApp is ready.
 */
export function startWhatsAppClient({ sessionDir, headless, puppeteerExecutablePath, logger = console }) {
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

  return new Promise((resolve, reject) => {
    client.on('qr', (qr) => {
      logger.log('\nScan this QR code with WhatsApp (Settings > Linked devices > Link a device):\n');
      qrcode.generate(qr, { small: true });
    });
    client.on('authenticated', () => logger.log('WhatsApp login accepted, loading chats…'));
    client.on('auth_failure', (message) => reject(new Error(`WhatsApp login failed: ${message}`)));
    client.on('disconnected', (reason) => logger.error(`WhatsApp disconnected: ${reason}`));
    client.once('ready', () => resolve(client));

    client.initialize().catch(reject);
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
 */
export async function resolveChannelId(client, { channelId, channelInviteCode }) {
  if (channelId) {
    return channelId;
  }
  if (!channelInviteCode) {
    return undefined;
  }
  const channel = await client.getChannelByInviteCode(inviteCodeFrom(channelInviteCode));
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
 * Prints the channels this account follows or owns, to help fill in the webhook URL.
 *
 * whatsapp-web.js only returns channels WhatsApp Web has already cached, and that cache usually fills in a
 * few seconds after the client is ready, so keep asking for a while before deciding there are none.
 */
export async function logChannels(client, { logger = console, attempts = 20, intervalMs = 3000 } = {}) {
  try {
    let channels = [];
    for (let attempt = 1; attempt <= attempts; attempt++) {
      channels = await client.getChannels();
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
      logger.log(`  ${channel.id._serialized}  ${channel.name}`);
    }
  } catch (error) {
    logger.error('Could not list WhatsApp channels:', error?.message ?? error);
  }
}
