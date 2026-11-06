import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { loadConfig } from '../src/config.js';
import { inviteCodeFrom } from '../src/whatsapp.js';

describe('loadConfig', () => {
  it('does not need a default channel', () => {
    const config = loadConfig({});
    assert.equal(config.channelId, undefined);
    assert.equal(config.channelInviteCode, undefined);
  });

  it('reads defaults and values', () => {
    const config = loadConfig({ WHATSAPP_CHANNEL_ID: ' 123@newsletter ', WEBHOOK_USERNAME: '' });
    assert.equal(config.channelId, '123@newsletter');
    assert.equal(config.port, 3000);
    assert.equal(config.webhookUsername, undefined);
    assert.equal(config.headless, true);
    assert.equal(config.readyTimeoutSeconds, 300);
    assert.equal(loadConfig({ WHATSAPP_READY_TIMEOUT_SECONDS: '60' }).readyTimeoutSeconds, 60);
  });

  it('rejects a bad port', () => {
    assert.throws(() => loadConfig({ WHATSAPP_CHANNEL_ID: 'x', PORT: 'abc' }), /PORT/);
  });

  it('rejects a bad ready timeout', () => {
    assert.throws(() => loadConfig({ WHATSAPP_READY_TIMEOUT_SECONDS: '0' }), /WHATSAPP_READY_TIMEOUT_SECONDS/);
  });
});

describe('inviteCodeFrom', () => {
  it('takes the code from a channel link or a bare code', () => {
    assert.equal(inviteCodeFrom('https://whatsapp.com/channel/0029VaAbc123?x=1'), '0029VaAbc123');
    assert.equal(inviteCodeFrom('0029VaAbc123'), '0029VaAbc123');
  });
});

describe('removeStaleChromeLocks', () => {
  it('deletes Chrome lock files, including dangling symlinks, and keeps the session', async () => {
    const { mkdtempSync, mkdirSync, symlinkSync, writeFileSync, readdirSync } = await import('node:fs');
    const { tmpdir } = await import('node:os');
    const { join } = await import('node:path');
    const { removeStaleChromeLocks } = await import('../src/whatsapp.js');

    const dir = mkdtempSync(join(tmpdir(), 'wwebjs-'));
    mkdirSync(join(dir, 'session'));
    symlinkSync('old-host-12345', join(dir, 'session', 'SingletonLock'));
    writeFileSync(join(dir, 'session', 'Local State'), '{}');

    removeStaleChromeLocks(dir);
    removeStaleChromeLocks(join(dir, 'missing'));
    assert.deepEqual(readdirSync(join(dir, 'session')), ['Local State']);
  });
});

describe('logChannels', () => {
  const fakeLogger = () => {
    const lines = [];
    return { lines, log: (...args) => lines.push(args.join(' ')), error: (...args) => lines.push(args.join(' ')) };
  };

  it('waits for channels that load after the client is ready', async () => {
    const { logChannels } = await import('../src/whatsapp.js');
    const results = [[], [], [{ id: '123@newsletter', name: 'News' }]];
    let calls = 0;
    const client = { pupPage: { evaluate: async () => results[calls++] } };
    const logger = fakeLogger();

    await logChannels(client, { logger, attempts: 5, intervalMs: 1 });

    assert.equal(calls, 3);
    assert.deepEqual(logger.lines, ['Channels on this WhatsApp account:', '  123@newsletter  News']);
  });

  it('says so when no channels show up', async () => {
    const { logChannels } = await import('../src/whatsapp.js');
    let calls = 0;
    const client = {
      pupPage: {
        evaluate: async () => {
          calls++;
          return [];
        },
      },
    };
    const logger = fakeLogger();

    await logChannels(client, { logger, attempts: 3, intervalMs: 1 });

    assert.equal(calls, 3);
    assert.match(logger.lines[0], /No WhatsApp channels found/);
  });
});
