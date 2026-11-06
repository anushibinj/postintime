import { timingSafeEqual } from 'node:crypto';
import express from 'express';
import multer from 'multer';

/**
 * Multer storage that reads uploaded files and throws them away. postintime sends the post's
 * `media` file with every webhook call; this client only posts the caption for now.
 */
const discardStorage = {
  _handleFile(_req, file, callback) {
    let size = 0;
    file.stream.on('data', (chunk) => {
      size += chunk.length;
    });
    file.stream.on('error', callback);
    file.stream.on('end', () => callback(null, { size }));
    file.stream.resume();
  },
  _removeFile(_req, _file, callback) {
    callback(null);
  },
};

/**
 * Builds the HTTP app that receives postintime webhook calls.
 *
 * @param {object} options
 * @param {(text: string) => Promise<void>} options.postToChannel sends text to the WhatsApp channel
 * @param {string} [options.webhookUsername] when set, requests need HTTP Basic auth
 * @param {string} [options.webhookPassword]
 * @param {Pick<Console, 'log' | 'error'>} [options.logger]
 */
export function createApp({ postToChannel, webhookUsername, webhookPassword = '', logger = console }) {
  const app = express();
  // postintime sends multipart/form-data (media, title, caption). JSON and form-urlencoded
  // bodies are accepted too, which makes testing with curl easier.
  const upload = multer({ storage: discardStorage, limits: { fields: 20, files: 5 } });

  app.get('/health', (_req, res) => {
    res.json({ status: 'ok' });
  });

  app.post(
    '/webhooks/post-to-channel',
    basicAuth(webhookUsername, webhookPassword),
    upload.any(),
    express.json({ limit: '1mb' }),
    express.urlencoded({ extended: false, limit: '1mb' }),
    async (req, res) => {
      // Form encoders may send line breaks as CRLF; WhatsApp only needs LF.
      const caption = typeof req.body?.caption === 'string' ? req.body.caption.replace(/\r\n?/g, '\n') : '';
      if (caption.trim() === '') {
        res.status(400).json({ error: 'CAPTION_REQUIRED', message: 'The "caption" field is empty or missing.' });
        return;
      }

      try {
        await postToChannel(caption);
        logger.log(`Posted to channel: ${preview(caption)}`);
        res.json({ status: 'sent' });
      } catch (error) {
        logger.error('Could not post to the WhatsApp channel:', error);
        res.status(502).json({ error: 'WHATSAPP_SEND_FAILED', message: error?.message ?? 'Sending failed.' });
      }
    },
  );

  // Bad multipart bodies and other request errors.
  app.use((error, _req, res, _next) => {
    const status = error instanceof multer.MulterError || error?.type === 'entity.parse.failed' ? 400 : 500;
    if (status === 500) {
      logger.error(error);
    }
    res.status(status).json({ error: 'BAD_REQUEST', message: error?.message ?? 'Request failed.' });
  });

  return app;
}

function basicAuth(username, password) {
  if (!username) {
    return (_req, _res, next) => next();
  }
  const expected = Buffer.from(`Basic ${Buffer.from(`${username}:${password}`).toString('base64')}`);
  return (req, res, next) => {
    const actual = Buffer.from(req.get('authorization') ?? '');
    if (actual.length === expected.length && timingSafeEqual(actual, expected)) {
      next();
      return;
    }
    res.set('WWW-Authenticate', 'Basic realm="postintime-whatsapp"');
    res.status(401).json({ error: 'UNAUTHORIZED', message: 'Missing or wrong webhook credentials.' });
  };
}

function preview(text) {
  const oneLine = text.replace(/\s+/g, ' ').trim();
  return oneLine.length > 60 ? `${oneLine.slice(0, 60)}…` : oneLine;
}
