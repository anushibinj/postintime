import { timingSafeEqual } from 'node:crypto';
import express from 'express';
import multer from 'multer';

/** Largest media file accepted. WhatsApp itself caps images at 16 MB and videos at 64 MB. */
export const MAX_MEDIA_BYTES = 64 * 1024 * 1024;

/**
 * Builds the HTTP app that receives postintime webhook calls.
 *
 * @param {object} options
 * @param {(channelId: string, text: string, media?: WebhookMedia) => Promise<void>} options.postToChannel sends
 *   the caption to a WhatsApp channel; when the webhook call has a media file, it is posted with the caption
 * @param {string | (() => string | undefined)} [options.defaultChannelId] channel used when the URL has no channel id
 * @param {() => boolean} [options.isReady] false while WhatsApp is still starting; webhook calls then get a 503
 * @param {string} [options.webhookUsername] when set, requests need HTTP Basic auth
 * @param {string} [options.webhookPassword]
 * @param {Pick<Console, 'log' | 'error'>} [options.logger]
 */
export function createApp({
  postToChannel,
  defaultChannelId,
  isReady = () => true,
  webhookUsername, webhookPassword = '',
  logger = console,
}) {
  const app = express();
  // postintime sends multipart/form-data (media, title, caption). JSON and form-urlencoded
  // bodies are accepted too, which makes testing with curl easier.
  // The post's image comes in the `media` field; keep it in memory to forward it to WhatsApp.
  const upload = multer({
    storage: multer.memoryStorage(),
    limits: { fields: 20, files: 5, fileSize: MAX_MEDIA_BYTES },
  });

  app.get('/health', (_req, res) => {
    // 503 until WhatsApp is logged in, so the Docker healthcheck only passes once posts can be sent.
    if (isReady()) {
      res.json({ status: 'ok' });
    } else {
      res.status(503).json({ status: 'starting' });
    }
  });

  app.post(
    // POST /webhooks/post-to-channel/<channel id>, or without the id to use the default channel.
    '/webhooks/post-to-channel{/:channelId}',
    basicAuth(webhookUsername, webhookPassword),
    upload.any(),
    express.json({ limit: '1mb' }),
    express.urlencoded({ extended: false, limit: '1mb' }),
    async (req, res) => {
      if (!isReady()) {
        res.set('Retry-After', '30');
        res.status(503).json({
          error: 'WHATSAPP_NOT_READY',
          message: 'WhatsApp is still starting (or waiting for the QR code to be scanned). Try again shortly.',
        });
        return;
      }
      const fallbackChannelId = typeof defaultChannelId === 'function' ? defaultChannelId() : defaultChannelId;
      const channelId = req.params.channelId ? toChannelId(req.params.channelId) : fallbackChannelId;
      if (!channelId) {
        res.status(400).json({
          error: 'CHANNEL_REQUIRED',
          message: 'Put the channel id in the URL: /webhooks/post-to-channel/<channel id>.',
        });
        return;
      }

      // Form encoders may send line breaks as CRLF; WhatsApp only needs LF.
      const caption = typeof req.body?.caption === 'string' ? req.body.caption.replace(/\r\n?/g, '\n') : '';
      const media = mediaFrom(req.files);
      if (caption.trim() === '' && !media) {
        res.status(400).json({ error: 'CAPTION_REQUIRED', message: 'The "caption" field is empty or missing.' });
        return;
      }

      try {
        if (media) {
          await postToChannel(channelId, caption, media);
          logger.log(`Posted ${media.mimetype} ${media.filename} to ${channelId}: ${preview(caption)}`);
        } else {
          await postToChannel(channelId, caption);
          logger.log(`Posted to ${channelId}: ${preview(caption)}`);
        }
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

/**
 * @typedef {object} WebhookMedia
 * @property {string} mimetype e.g. image/png
 * @property {string} filename original file name, e.g. photo.png
 * @property {Buffer} data the file contents
 */

/**
 * Picks the post's media file from the uploaded files: the `media` field postintime sends, or else the first
 * non-empty file (handy when testing with curl). Returns undefined when there is none.
 *
 * @returns {WebhookMedia | undefined}
 */
export function mediaFrom(files) {
  const nonEmpty = (files ?? []).filter((file) => file.buffer?.length > 0);
  const file = nonEmpty.find((candidate) => candidate.fieldname === 'media') ?? nonEmpty[0];
  if (!file) {
    return undefined;
  }
  return {
    mimetype: file.mimetype || 'application/octet-stream',
    filename: file.originalname || 'media',
    data: file.buffer,
  };
}

/**
 * Channel ids look like 120363000000000000@newsletter. The "@newsletter" suffix may be left out of the URL.
 */
export function toChannelId(value) {
  const id = value.trim();
  return id.includes('@') ? id : `${id}@newsletter`;
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
