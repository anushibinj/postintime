import { loadConfig } from './config.js';
import { createApp } from './server.js';
import { logChannels, resolveChannelId, startWhatsAppClient } from './whatsapp.js';

// Longer than the 30 second idle timeout of Java's HttpClient connection pool.
const KEEP_ALIVE_TIMEOUT_MS = 65 * 1000;

async function main() {
  const config = loadConfig();

  console.log('Starting WhatsApp…');
  const client = await startWhatsAppClient(config);
  console.log('WhatsApp is ready.');
  // Channels can take a while to load; list them in the background so the webhook server starts now.
  logChannels(client);

  const defaultChannelId = await resolveChannelId(client, config);
  if (defaultChannelId) {
    console.log(`Default channel: ${defaultChannelId}`);
  }

  const app = createApp({
    postToChannel: async (channelId, text) => {
      await client.sendMessage(channelId, text);
    },
    defaultChannelId,
    webhookUsername: config.webhookUsername,
    webhookPassword: config.webhookPassword,
  });

  const server = app.listen(config.port, config.host, () => {
    const { port } = server.address();
    console.log(`Listening for postintime webhooks on http://${config.host}:${port}/webhooks/post-to-channel/<channel id>`);
  });
  // postintime waits up to 15 minutes for a webhook to answer; don't cut slow sends off early.
  server.requestTimeout = 15 * 60 * 1000;
  // postintime (Java HttpClient) keeps idle connections open for 30 seconds and reuses them.
  // Node closes idle connections after 5 seconds by default, so a post sent 5-30 seconds after
  // the previous one went out on a socket Node had already closed, and failed with
  // "header parser received no bytes". Keep idle connections open longer than Java does.
  server.keepAliveTimeout = KEEP_ALIVE_TIMEOUT_MS;
  server.headersTimeout = KEEP_ALIVE_TIMEOUT_MS + 1000;

  const shutdown = async (signal) => {
    console.log(`\n${signal} received, shutting down…`);
    server.close();
    await client.destroy().catch(() => {});
    process.exit(0);
  };
  process.once('SIGINT', () => shutdown('SIGINT'));
  process.once('SIGTERM', () => shutdown('SIGTERM'));
}

main().catch((error) => {
  console.error(error?.message ?? error);
  process.exit(1);
});
