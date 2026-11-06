/**
 * Reads the client settings from environment variables (or a `.env` file, see `pnpm start`).
 */
export function loadConfig(env = process.env) {
  const config = {
    port: Number.parseInt(env.PORT ?? '3000', 10),
    host: env.HOST ?? '0.0.0.0',
    // Optional default channel, used when a webhook URL has no channel id: either its id
    // (e.g. 120363000000000000@newsletter) or the invite code from its link (https://whatsapp.com/channel/<code>).
    channelId: blankToUndefined(env.WHATSAPP_CHANNEL_ID),
    channelInviteCode: blankToUndefined(env.WHATSAPP_CHANNEL_INVITE_CODE),
    // Optional HTTP Basic auth, matching the webhook username/password set on the postintime social account.
    webhookUsername: blankToUndefined(env.WEBHOOK_USERNAME),
    webhookPassword: env.WEBHOOK_PASSWORD ?? '',
    // Folder where the WhatsApp login session is kept, so you only scan the QR code once.
    sessionDir: env.WHATSAPP_SESSION_DIR ?? '.wwebjs_auth',
    headless: env.HEADLESS !== 'false',
    puppeteerExecutablePath: blankToUndefined(env.PUPPETEER_EXECUTABLE_PATH),
  };

  if (!Number.isInteger(config.port) || config.port < 0 || config.port > 65535) {
    throw new Error(`PORT must be a number between 0 and 65535, got "${env.PORT}".`);
  }
  return config;
}

function blankToUndefined(value) {
  if (value === undefined || value.trim() === '') {
    return undefined;
  }
  return value.trim();
}
