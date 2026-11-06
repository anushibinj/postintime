import assert from 'node:assert/strict';
import { EventEmitter } from 'node:events';
import { describe, it } from 'node:test';
import { waitForReady } from '../src/whatsapp.js';

function recordingLogger() {
  const lines = [];
  return { lines, log: (line) => lines.push(line), error: (line) => lines.push(`ERROR ${line}`) };
}

/** A whatsapp-web.js client stand-in with a puppeteer page that can report errors. */
function fakeClient() {
  const client = new EventEmitter();
  client.pupPage = new EventEmitter();
  return client;
}

describe('waitForReady', () => {
  it('resolves with the client when it is ready, logging loading progress once per value', async () => {
    const client = fakeClient();
    const logger = recordingLogger();
    const ready = waitForReady(client, { timeoutMs: 1000, logger });
    client.emit('authenticated');
    client.emit('authenticated');
    client.emit('loading_screen', 40);
    client.emit('loading_screen', 40);
    client.emit('ready');
    assert.equal(await ready, client);
    assert.deepEqual(logger.lines, ['WhatsApp login accepted, loading chats…', 'Loading WhatsApp: 40%']);
  });

  it('gives up when chats do not load in time, and logs page errors meanwhile', async () => {
    const client = fakeClient();
    const logger = recordingLogger();
    const ready = waitForReady(client, { timeoutMs: 20, logger });
    client.emit('authenticated');
    client.pupPage.emit('pageerror', new Error("Cannot read properties of undefined (reading 'Chat')"));
    client.pupPage.emit('console', { type: () => 'error', text: () => 'module missing' });
    client.pupPage.emit('console', { type: () => 'log', text: () => 'harmless' });
    await assert.rejects(ready, /did not finish loading chats within 0 seconds/);
    assert.deepEqual(logger.lines.slice(1), [
      "ERROR WhatsApp Web page error: Cannot read properties of undefined (reading 'Chat')",
      'ERROR WhatsApp Web console error: module missing',
    ]);

    client.pupPage.emit('pageerror', new Error('after giving up'));
    assert.equal(logger.lines.length, 3);
  });

  it('does not time out while waiting for the QR code to be scanned', async () => {
    const client = fakeClient();
    const ready = waitForReady(client, { timeoutMs: 10, logger: recordingLogger() });
    await new Promise((resolve) => setTimeout(resolve, 30));
    client.emit('authenticated');
    client.emit('ready');
    assert.equal(await ready, client);
  });

  it('rejects when the login fails or initialize() fails', async () => {
    const failedLogin = fakeClient();
    const login = waitForReady(failedLogin, { timeoutMs: 1000, logger: recordingLogger() });
    failedLogin.emit('auth_failure', 'bad session');
    await assert.rejects(login, /WhatsApp login failed: bad session/);

    const failedInit = fakeClient();
    const init = waitForReady(failedInit, { timeoutMs: 1000, logger: recordingLogger() });
    failedInit.emit('init_failure', new Error('Chrome did not start'));
    await assert.rejects(init, /Chrome did not start/);
  });
});
