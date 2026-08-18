import { Button, Card, Col, Form, Input, Modal, Row, Select, Space, Tooltip, Typography, message } from 'antd';
import { Copy, KeyRound, Plus, RefreshCw, Trash2 } from 'lucide-react';
import { useState } from 'react';
import { format } from 'date-fns';
import { useAuth } from '../../app/providers/AuthProvider';
import { useApiTokenMutations, useApiTokens } from '../../hooks/useApiTokens';
import type { ApiToken } from '../../types';

const EXPIRY_OPTIONS = [
  { value: 'never', label: 'Never expires' },
  { value: '7', label: '7 days' },
  { value: '30', label: '30 days' },
  { value: '90', label: '90 days' },
  { value: '365', label: '1 year' },
];

function expiryFromPreset(preset: string): string | null {
  if (preset === 'never') {
    return null;
  }
  const days = Number(preset);
  return new Date(Date.now() + days * 24 * 60 * 60 * 1000).toISOString();
}

function formatExpiry(expiresAt?: string | null): string {
  if (!expiresAt) {
    return 'Never expires';
  }
  return `Expires ${format(new Date(expiresAt), 'MMM d, yyyy')}`;
}

export function SettingsPage() {
  const { user } = useAuth();
  const { data: tokens = [], isLoading } = useApiTokens();
  const mutations = useApiTokenMutations();
  const [createOpen, setCreateOpen] = useState(false);
  const [secretToken, setSecretToken] = useState<string | null>(null);
  const [form] = Form.useForm<{ name: string; expiry: string }>();

  const openCreate = () => {
    form.resetFields();
    form.setFieldsValue({ expiry: 'never' });
    setCreateOpen(true);
  };

  const handleCreate = async (values: { name: string; expiry: string }) => {
    try {
      const created = await mutations.create.mutateAsync({
        name: values.name,
        expiresAt: expiryFromPreset(values.expiry),
      });
      setCreateOpen(false);
      setSecretToken(created.token || null);
      message.success('API token created');
    } catch {
      message.error('Failed to create API token');
    }
  };

  const handleRefresh = (token: ApiToken) => {
    Modal.confirm({
      title: 'Refresh this token?',
      content: 'The current secret will stop working immediately. A new secret will be shown once.',
      onOk: async () => {
        try {
          const refreshed = await mutations.refresh.mutateAsync({ tokenId: token.id });
          setSecretToken(refreshed.token || null);
          message.success('API token refreshed');
        } catch {
          message.error('Failed to refresh API token');
        }
      },
    });
  };

  const handleExpiryChange = (token: ApiToken, expiry: string) => {
    const neverExpires = expiry === 'never';
    mutations.update.mutate(
      {
        tokenId: token.id,
        data: neverExpires ? { neverExpires: true } : { expiresAt: expiryFromPreset(expiry) },
      },
      {
        onSuccess: () => message.success('Expiry updated'),
        onError: () => message.error('Failed to update expiry'),
      },
    );
  };

  const copySecret = async () => {
    if (!secretToken) {
      return;
    }
    await navigator.clipboard.writeText(secretToken);
    message.success('Token copied');
  };

  return (
    <div>
      <Typography.Title level={2}>Settings</Typography.Title>
      <Typography.Paragraph>Email: {user?.email}</Typography.Paragraph>

      <Space style={{ width: '100%', justifyContent: 'space-between', marginBottom: 16 }}>
        <div>
          <Typography.Title level={4} style={{ margin: 0 }}>API tokens</Typography.Title>
          <Typography.Text type="secondary">
            Use a token as a Bearer credential for REST calls to the PostInTime API.
          </Typography.Text>
        </div>
        <Button type="primary" icon={<Plus size={16} />} onClick={openCreate}>New token</Button>
      </Space>

      {isLoading ? (
        <Typography.Text>Loading...</Typography.Text>
      ) : tokens.length === 0 ? (
        <Typography.Paragraph type="secondary">No API tokens yet.</Typography.Paragraph>
      ) : (
        <Row gutter={[16, 16]}>
          {tokens.map((token) => (
            <Col key={token.id} xs={24} md={12} lg={8}>
              <Card
                actions={[
                  <Tooltip title="Refresh secret" key="refresh">
                    <span onClick={() => handleRefresh(token)}><RefreshCw size={16} /></span>
                  </Tooltip>,
                  <Tooltip title="Delete" key="delete">
                    <span
                      onClick={() => {
                        Modal.confirm({
                          title: 'Delete this token?',
                          content: 'Requests using this token will fail immediately.',
                          onOk: () => mutations.remove.mutate(token.id),
                        });
                      }}
                    >
                      <Trash2 size={16} style={{ color: '#ff4d4f' }} />
                    </span>
                  </Tooltip>,
                ]}
              >
                <Card.Meta
                  avatar={<KeyRound size={20} />}
                  title={token.name}
                  description={
                    <>
                      <Typography.Text code>{token.tokenPrefix}…</Typography.Text>
                      <Typography.Paragraph type="secondary" style={{ marginTop: 8, marginBottom: 8 }}>
                        {formatExpiry(token.expiresAt)}
                      </Typography.Paragraph>
                      <Select
                        size="small"
                        style={{ width: '100%' }}
                        placeholder="Change expiry"
                        onClick={(event) => event.stopPropagation()}
                        onChange={(value) => handleExpiryChange(token, value)}
                        options={EXPIRY_OPTIONS}
                      />
                      {token.lastUsedAt && (
                        <Typography.Paragraph type="secondary" style={{ marginTop: 8, marginBottom: 0 }}>
                          Last used {format(new Date(token.lastUsedAt), 'MMM d, yyyy')}
                        </Typography.Paragraph>
                      )}
                    </>
                  }
                />
              </Card>
            </Col>
          ))}
        </Row>
      )}

      <Modal
        title="Create API token"
        open={createOpen}
        onCancel={() => setCreateOpen(false)}
        onOk={() => form.submit()}
        confirmLoading={mutations.create.isPending}
      >
        <Form form={form} layout="vertical" onFinish={handleCreate}>
          <Form.Item name="name" label="Name" rules={[{ required: true, message: 'Give this token a name' }]}>
            <Input placeholder="CI pipeline" />
          </Form.Item>
          <Form.Item name="expiry" label="Expiry" rules={[{ required: true }]}>
            <Select options={EXPIRY_OPTIONS} />
          </Form.Item>
        </Form>
      </Modal>

      <Modal
        title="Copy your API token"
        open={!!secretToken}
        onCancel={() => setSecretToken(null)}
        footer={[
          <Button key="copy" type="primary" icon={<Copy size={16} />} onClick={copySecret}>Copy token</Button>,
        ]}
      >
        <Typography.Paragraph>
          This secret is shown only once. Store it somewhere safe.
        </Typography.Paragraph>
        <Input.TextArea value={secretToken || ''} readOnly autoSize />
      </Modal>
    </div>
  );
}
