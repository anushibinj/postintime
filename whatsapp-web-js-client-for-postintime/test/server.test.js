import assert from 'node:assert/strict';
import { after, before, beforeEach, describe, it } from 'node:test';
import { createApp } from '../src/server.js';

const silentLogger = { log() {}, error() {} };

function startServer(options) {
  const app = createApp({ logger: silentLogger, ...options });
  return new Promise((resolve) => {
    const server = app.listen(0, '127.0.0.1', () => {
      resolve({ server, url: `http://127.0.0.1:${server.address().port}/webhooks/post-to-channel` });
    });
  });
}

/** The multipart body postintime sends: media (optional), title, caption. */
function postintimeForm({ caption, withMedia = true }) {
  const form = new FormData();
  if (withMedia) {
    form.append('media', new Blob([Buffer.alloc(1024, 1)], { type: 'image/png' }), 'photo.png');
  }
  form.append('title', 'My title');
  if (caption !== undefined) {
    form.append('caption', caption);
  }
  return form;
}

describe('POST /webhooks/post-to-channel', () => {
  let sent;
  let failNext;
  let server;
  let url;

  before(async () => {
    ({ server, url } = await startServer({
      postToChannel: async (text) => {
        if (failNext) {
          failNext = false;
          throw new Error('not an admin of this channel');
        }
        sent.push(text);
      },
    }));
  });
  after(() => server.close());
  beforeEach(() => {
    sent = [];
    failNext = false;
  });

  it('sends the caption from postintime multipart form data', async () => {
    const res = await fetch(url, { method: 'POST', body: postintimeForm({ caption: 'Hello *channel*\nline 2' }) });
    assert.equal(res.status, 200);
    assert.deepEqual(await res.json(), { status: 'sent' });
    assert.deepEqual(sent, ['Hello *channel*\nline 2']);
  });

  it('works when the post has no media', async () => {
    const res = await fetch(url, { method: 'POST', body: postintimeForm({ caption: 'Text only', withMedia: false }) });
    assert.equal(res.status, 200);
    assert.deepEqual(sent, ['Text only']);
  });

  it('accepts a JSON body', async () => {
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ caption: 'From JSON' }),
    });
    assert.equal(res.status, 200);
    assert.deepEqual(sent, ['From JSON']);
  });

  it('rejects a missing or blank caption', async () => {
    for (const caption of [undefined, '   ']) {
      const res = await fetch(url, { method: 'POST', body: postintimeForm({ caption }) });
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
      postToChannel: async (text) => sent.push(text),
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
    assert.deepEqual(sent, ['Hi']);
  });
});
