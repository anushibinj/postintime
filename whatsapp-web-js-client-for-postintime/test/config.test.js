import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { loadConfig } from '../src/config.js';
import { inviteCodeFrom } from '../src/whatsapp.js';

describe('loadConfig', () => {
  it('needs a channel', () => {
    assert.throws(() => loadConfig({}), /WHATSAPP_CHANNEL_ID/);
  });

  it('reads defaults and values', () => {
    const config = loadConfig({ WHATSAPP_CHANNEL_ID: ' 123@newsletter ', WEBHOOK_USERNAME: '' });
    assert.equal(config.channelId, '123@newsletter');
    assert.equal(config.port, 3000);
    assert.equal(config.webhookUsername, undefined);
    assert.equal(config.headless, true);
  });

  it('rejects a bad port', () => {
    assert.throws(() => loadConfig({ WHATSAPP_CHANNEL_ID: 'x', PORT: 'abc' }), /PORT/);
  });
});

describe('inviteCodeFrom', () => {
  it('takes the code from a channel link or a bare code', () => {
    assert.equal(inviteCodeFrom('https://whatsapp.com/channel/0029VaAbc123?x=1'), '0029VaAbc123');
    assert.equal(inviteCodeFrom('0029VaAbc123'), '0029VaAbc123');
  });
});
