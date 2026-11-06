import { loadConfig } from './config.js';
import { createApp } from './server.js';
import { logChannels, resolveChannelId, startWhatsAppClient } from './whatsapp.js';

async function main() {
  const config = loadConfig();

  console.log('Starting WhatsApp…');
  const client = await startWhatsAppClient(config);
  console.log('WhatsApp is ready.');
  await logChannels(client);

  const channelId = await resolveChannelId(client, config);
  console.log(`Posting to channel ${channelId}`);

  const app = createApp({
    postToChannel: async (text) => {
      await client.sendMessage(channelId, text);
    },
    webhookUsername: config.webhookUsername,
    webhookPassword: config.webhookPassword,
  });

  const server = app.listen(config.port, config.host, () => {
    const { port } = server.address();
    console.log(`Listening for postintime webhooks on http://${config.host}:${port}/webhooks/post-to-channel`);
  });
  // postintime waits up to 15 minutes for a webhook to answer; don't cut slow sends off early.
  server.requestTimeout = 15 * 60 * 1000;

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
