import whatsappWeb from 'whatsapp-web.js';
import { loadConfig } from './config.js';
import { createApp } from './server.js';
import { logChannels, resolveChannelId, startWhatsAppClient } from './whatsapp.js';

// Longer than the 30 second idle timeout of Java's HttpClient connection pool.
const KEEP_ALIVE_TIMEOUT_MS = 65 * 1000;
const { MessageMedia } = whatsappWeb;

async function main() {
  const config = loadConfig();
  let client;
  let defaultChannelId;

  // Start the webhook server before WhatsApp: logging in can take minutes (or wait for a QR scan).
  // If nothing listened on the port meanwhile, Docker's port mapping would accept postintime's
  // connection and close it with no reply ("header parser received no bytes"). Now it gets a 503.
  const app = createApp({
    postToChannel: async (channelId, text, media) => {
      if (media) {
        // Post the image with the caption under it, like posting a photo in the WhatsApp app.
        const attachment = new MessageMedia(media.mimetype, media.data.toString('base64'), media.filename);
        const sent = await client.sendMessage(channelId, attachment, text ? { caption: text } : {});
        // whatsapp-web.js returns null (and only logs a warning) for media types channels don't support.
        if (!sent) {
          throw new Error(`WhatsApp channels do not accept ${media.mimetype} media.`);
        }
      } else {
        await client.sendMessage(channelId, text);
      }
    },
    isReady: () => client !== undefined,
    defaultChannelId: () => defaultChannelId,
    webhookUsername: config.webhookUsername,
    webhookPassword: config.webhookPassword,
  });

  const server = app.listen(config.port, config.host, () => {
    const { port } = server.address();
    console.log(`Listening for postintime webhooks on http://${config.host}:${port}/webhooks/post-to-channel/<channel id>`);
  });
  server.on('error', (error) => {
    console.error(`Webhook server error: ${error.message}`);
    process.exit(1);
  });
  // postintime waits up to 15 minutes for a webhook to answer; don't cut slow sends off early.
  server.requestTimeout = 15 * 60 * 1000;
  // postintime (Java HttpClient) keeps idle connections open for 30 seconds and reuses them.
  // Node closes idle connections after 5 seconds by default, so a post sent 5-30 seconds after
  // the previous one could go out on a socket Node had already closed, and fail with
  // "header parser received no bytes". Keep idle connections open longer than Java does.
  server.keepAliveTimeout = KEEP_ALIVE_TIMEOUT_MS;
  server.headersTimeout = KEEP_ALIVE_TIMEOUT_MS + 1000;

  let whatsapp;
  const shutdown = async (signal) => {
    console.log(`\n${signal} received, shutting down…`);
    server.close();
    await whatsapp?.destroy().catch(() => {});
    process.exit(0);
  };
  process.once('SIGINT', () => shutdown('SIGINT'));
  process.once('SIGTERM', () => shutdown('SIGTERM'));

  console.log('Starting WhatsApp…');
  whatsapp = await startWhatsAppClient(config);
  console.log('WhatsApp is ready.');
  // Channels can take a while to load; list them in the background.
  logChannels(whatsapp);

  client = whatsapp;

  // A default channel that can't be found shouldn't stop the client: URLs with a channel id still work.
  try {
    defaultChannelId = await resolveChannelId(whatsapp, config);
    if (defaultChannelId) {
      console.log(`Default channel: ${defaultChannelId}`);
    }
  } catch (error) {
    console.error(`No default channel: ${error?.message ?? error}`);
  }
}

main().catch((error) => {
  console.error(error?.message ?? error);
  process.exit(1);
});
