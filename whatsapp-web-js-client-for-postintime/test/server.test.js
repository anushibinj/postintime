import assert from 'node:assert/strict';
import { after, before, beforeEach, describe, it } from 'node:test';
import { createApp, toChannelId } from '../src/server.js';

const silentLogger = { log() {}, error() {} };
const CHANNEL = '120363000000000001@newsletter';

function startServer(options) {
  const app = createApp({ logger: silentLogger, ...options });
  return new Promise((resolve) => {
    const server = app.listen(0, '127.0.0.1', () => {
      const base = `http://127.0.0.1:${server.address().port}/webhooks/post-to-channel`;
      resolve({ server, base, url: `${base}/${CHANNEL}` });
    });
  });
}

/** The multipart body postintime sends: media (optional), title, caption. */
const IMAGE = Buffer.alloc(1024, 1);

function postintimeForm({ caption, withMedia = true }) {
  const form = new FormData();
  if (withMedia) {
    form.append('media', new Blob([IMAGE], { type: 'image/png' }), 'photo.png');
  }
  form.append('title', 'My title');
  if (caption !== undefined) {
    form.append('caption', caption);
  }
  return form;
}

describe('POST /webhooks/post-to-channel/:channelId', () => {
  let sent;
  let media;
  let failNext;
  let server;
  let base;
  let url;

  before(async () => {
    ({ server, base, url } = await startServer({
      postToChannel: async (channelId, text, file) => {
        if (failNext) {
          failNext = false;
          throw new Error('not an admin of this channel');
        }
        sent.push([channelId, text]);
        media.push(file);
      },
    }));
  });
  after(() => server.close());
  beforeEach(() => {
    sent = [];
    media = [];
    failNext = false;
  });

  it('sends the image with the caption from postintime multipart form data', async () => {
    const res = await fetch(url, { method: 'POST', body: postintimeForm({ caption: 'Hello *channel*\nline 2' }) });
    assert.equal(res.status, 200);
    assert.deepEqual(await res.json(), { status: 'sent' });
    assert.deepEqual(sent, [[CHANNEL, 'Hello *channel*\nline 2']]);
    assert.equal(media.length, 1);
    assert.equal(media[0].mimetype, 'image/png');
    assert.equal(media[0].filename, 'photo.png');
    assert.ok(media[0].data.equals(IMAGE));
  });

  it('sends text only when the post has no media', async () => {
    const res = await fetch(url, { method: 'POST', body: postintimeForm({ caption: 'Text only', withMedia: false }) });
    assert.equal(res.status, 200);
    assert.deepEqual(sent, [[CHANNEL, 'Text only']]);
    assert.deepEqual(media, [undefined]);
  });

  it('sends the image alone when the caption is blank', async () => {
    const res = await fetch(url, { method: 'POST', body: postintimeForm({ caption: '' }) });
    assert.equal(res.status, 200);
    assert.deepEqual(sent, [[CHANNEL, '']]);
    assert.equal(media[0].filename, 'photo.png');
  });

  it('ignores an empty media file', async () => {
    const form = new FormData();
    form.append('media', new Blob([], { type: 'image/png' }), 'empty.png');
    form.append('caption', 'Hi');
    const res = await fetch(url, { method: 'POST', body: form });
    assert.equal(res.status, 200);
    assert.deepEqual(media, [undefined]);
  });

  it('accepts a JSON body', async () => {
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ caption: 'From JSON' }),
    });
    assert.equal(res.status, 200);
    assert.deepEqual(sent, [[CHANNEL, 'From JSON']]);
  });

  it('adds @newsletter when the URL has a bare or URL-encoded channel id', async () => {
    for (const id of ['120363000000000001', encodeURIComponent(CHANNEL)]) {
      const res = await fetch(`${base}/${id}`, { method: 'POST', body: postintimeForm({ caption: 'Hi' }) });
      assert.equal(res.status, 200);
    }
    assert.deepEqual(sent, [
      [CHANNEL, 'Hi'],
      [CHANNEL, 'Hi'],
    ]);
  });

  it('needs a channel id when there is no default channel', async () => {
    const res = await fetch(base, { method: 'POST', body: postintimeForm({ caption: 'Hi' }) });
    assert.equal(res.status, 400);
    assert.equal((await res.json()).error, 'CHANNEL_REQUIRED');
    assert.deepEqual(sent, []);
  });

  it('rejects a missing or blank caption when there is no media', async () => {
    for (const caption of [undefined, '   ']) {
      const res = await fetch(url, { method: 'POST', body: postintimeForm({ caption, withMedia: false }) });
      assert.equal(res.status, 400);
      assert.equal((await res.json()).error, 'CAPTION_REQUIRED');
    }
    assert.deepEqual(sent, []);
  });

  it('returns 502 with the reason when WhatsApp fails', async () => {
    failNext = true;
    const res = await fetch(url, { method: 'POST', body: postintimeForm({ caption: 'Hi' }) });
    assert.equal(res.status, 502);
    assert.deepEqual(await res.json(), { error: 'WHATSAPP_SEND_FAILED', message: 'not an admin of this channel' });
  });
});

describe('Basic auth', () => {
  let sent;
  let server;
  let url;
  const authHeader = (user, pass) => ({ authorization: `Basic ${Buffer.from(`${user}:${pass}`).toString('base64')}` });

  before(async () => {
    sent = [];
    ({ server, url } = await startServer({
      postToChannel: async (channelId, text) => sent.push([channelId, text]),
      webhookUsername: 'postintime',
      webhookPassword: 's3cret',
    }));
  });
  after(() => server.close());

  it('rejects requests without or with wrong credentials', async () => {
    for (const headers of [{}, authHeader('postintime', 'wrong')]) {
      const res = await fetch(url, { method: 'POST', headers, body: postintimeForm({ caption: 'Hi' }) });
      assert.equal(res.status, 401);
    }
    assert.deepEqual(sent, []);
  });

  it('accepts the right credentials', async () => {
    const res = await fetch(url, {
      method: 'POST',
      headers: authHeader('postintime', 's3cret'),
      body: postintimeForm({ caption: 'Hi' }),
    });
    assert.equal(res.status, 200);
    assert.deepEqual(sent, [[CHANNEL, 'Hi']]);
  });
});

describe('default channel', () => {
  it('is used when the URL has no channel id, and the URL id wins over it', async () => {
    const sent = [];
    const { server, base } = await startServer({
      postToChannel: async (channelId, text) => sent.push([channelId, text]),
      defaultChannelId: 'default@newsletter',
    });
    try {
      await fetch(base, { method: 'POST', body: postintimeForm({ caption: 'A' }) });
      await fetch(`${base}/other@newsletter`, { method: 'POST', body: postintimeForm({ caption: 'B' }) });
      assert.deepEqual(sent, [
        ['default@newsletter', 'A'],
        ['other@newsletter', 'B'],
      ]);
    } finally {
      server.close();
    }
  });
});

describe('while WhatsApp is starting', () => {
  it('answers webhook calls with 503 instead of dropping them, then sends once ready', async () => {
    const sent = [];
    let ready = false;
    let defaultChannelId;
    const { server, base, url } = await startServer({
      postToChannel: async (channelId, text) => sent.push([channelId, text]),
      isReady: () => ready,
      defaultChannelId: () => defaultChannelId,
    });
    try {
      const health = await fetch(base.replace('/webhooks/post-to-channel', '/health'));
      assert.equal(health.status, 503);
      assert.deepEqual(await health.json(), { status: 'starting' });

      const early = await fetch(url, { method: 'POST', body: postintimeForm({ caption: 'Too early' }) });
      assert.equal(early.status, 503);
      assert.equal(early.headers.get('retry-after'), '30');
      assert.equal((await early.json()).error, 'WHATSAPP_NOT_READY');
      assert.deepEqual(sent, []);

      ready = true;
      defaultChannelId = 'default@newsletter';
      const later = await fetch(base, { method: 'POST', body: postintimeForm({ caption: 'Now' }) });
      assert.equal(later.status, 200);
      assert.deepEqual(sent, [['default@newsletter', 'Now']]);
    } finally {
      server.close();
    }
  });
});

describe('toChannelId', () => {
  it('keeps full ids and trims', () => {
    assert.equal(toChannelId(' 123@newsletter '), '123@newsletter');
    assert.equal(toChannelId('123'), '123@newsletter');
  });
});
