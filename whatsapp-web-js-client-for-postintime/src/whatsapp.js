import qrcode from 'qrcode-terminal';
import whatsappWeb from 'whatsapp-web.js';

const { Client, LocalAuth } = whatsappWeb;

/**
 * Starts whatsapp-web.js, prints the login QR code in the terminal when there is no saved
 * session, and resolves with the logged-in client once WhatsApp is ready.
 */
export function startWhatsAppClient({ sessionDir, headless, puppeteerExecutablePath, logger = console }) {
  const client = new Client({
    authStrategy: new LocalAuth({ dataPath: sessionDir }),
    puppeteer: {
      headless,
      executablePath: puppeteerExecutablePath,
      // Needed when Chrome runs as root, for example inside Docker.
      args: ['--no-sandbox', '--disable-setuid-sandbox'],
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

/** Prints the channels this account follows or owns, to help fill in WHATSAPP_CHANNEL_ID. */
export async function logChannels(client, logger = console) {
  try {
    const channels = await client.getChannels();
    if (channels.length === 0) {
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
