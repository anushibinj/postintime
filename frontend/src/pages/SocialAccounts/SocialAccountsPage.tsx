import { Button, Card, Col, Form, Input, Modal, Radio, Row, Select, Space, Tooltip, Typography, message } from 'antd';
import { ArrowLeft, Pencil, Plus, Power, PowerOff, Trash2 } from 'lucide-react';
import { useNavigate, useParams } from 'react-router-dom';
import { useState } from 'react';
import { useSocialAccounts, useSocialAccountMutations } from '../../hooks/useSocialAccounts';
import type { Platform, PostingMode, SocialAccount, WebhookAuthType } from '../../types';

const PLATFORMS: { value: Platform; label: string }[] = [
  { value: 'linkedin', label: 'LinkedIn' },
  { value: 'instagram', label: 'Instagram' },
  { value: 'whatsapp', label: 'WhatsApp' },
  { value: 'youtube', label: 'YouTube' },
  { value: 'x', label: 'X' },
  { value: 'facebook', label: 'Facebook' },
  { value: 'threads', label: 'Threads' },
];

type AccountFormValues = {
  platform: Platform;
  name: string;
  profileUrl?: string;
  postingMode: PostingMode;
  webhookUrl?: string;
  webhookAuthType: WebhookAuthType;
  webhookUsername?: string;
  webhookPassword?: string;
};

export function SocialAccountsPage() {
  const { channelId } = useParams();
  const navigate = useNavigate();
  const { data: accounts = [], isLoading } = useSocialAccounts(channelId);
  const mutations = useSocialAccountMutations(channelId!);
  const [modalOpen, setModalOpen] = useState(false);
  const [editing, setEditing] = useState<SocialAccount | null>(null);
  const [form] = Form.useForm<AccountFormValues>();
  const postingMode = Form.useWatch('postingMode', form);
  const webhookAuthType = Form.useWatch('webhookAuthType', form);

  const openCreate = () => {
    setEditing(null);
    form.resetFields();
    form.setFieldsValue({ postingMode: 'manual', webhookAuthType: 'none' });
    setModalOpen(true);
  };

  const openEdit = (account: SocialAccount) => {
    setEditing(account);
    form.setFieldsValue({
      platform: account.platform,
      name: account.name,
      profileUrl: account.profileUrl,
      postingMode: account.postingMode === 'webhook' ? 'webhook' : 'manual',
      webhookUrl: account.webhookUrl || undefined,
      webhookAuthType: account.webhookAuthType || 'none',
      webhookUsername: account.webhookUsername || undefined,
      webhookPassword: undefined,
    });
    setModalOpen(true);
  };

  const handleSave = async (values: AccountFormValues) => {
    try {
      const payload = {
        platform: values.platform,
        name: values.name,
        profileUrl: values.profileUrl,
        postingMode: values.postingMode,
        webhookUrl: values.postingMode === 'webhook' ? values.webhookUrl : undefined,
        webhookAuthType: values.postingMode === 'webhook' ? values.webhookAuthType : 'none',
        webhookUsername: values.postingMode === 'webhook' && values.webhookAuthType === 'basic'
          ? values.webhookUsername
          : undefined,
        webhookPassword: values.postingMode === 'webhook' && values.webhookAuthType === 'basic'
          ? values.webhookPassword
          : undefined,
      };
      if (editing) {
        await mutations.update.mutateAsync({ accountId: editing.id, data: payload });
      } else {
        await mutations.create.mutateAsync(payload);
      }
      setModalOpen(false);
      message.success('Account saved');
    } catch (error) {
      message.error(error instanceof Error ? error.message : 'Failed to save account');
    }
  };

  return (
    <div>
      <Button
        type="text"
        icon={<ArrowLeft size={16} />}
        onClick={() => navigate(`/channels/${channelId}`)}
        style={{ paddingLeft: 0, marginBottom: 8 }}
      >
        Back to Posts
      </Button>
      <Space style={{ width: '100%', justifyContent: 'space-between', marginBottom: 24 }}>
        <Typography.Title level={2} style={{ margin: 0 }}>Social Accounts</Typography.Title>
        <Button type="primary" icon={<Plus size={16} />} onClick={openCreate}>Add Account</Button>
      </Space>

      {isLoading ? <Typography.Text>Loading...</Typography.Text> : (
        <Row gutter={[16, 16]}>
          {accounts.map((account) => (
            <Col key={account.id} xs={24} sm={12} lg={8}>
              <Card
                hoverable
                actions={[
                  <Tooltip title="Edit" key="edit">
                    <span onClick={() => openEdit(account)}><Pencil size={16} /></span>
                  </Tooltip>,
                  account.enabled ? (
                    <Tooltip title="Disable" key="toggle">
                      <span onClick={() => mutations.disable.mutate(account.id)}><PowerOff size={16} /></span>
                    </Tooltip>
                  ) : (
                    <Tooltip title="Enable" key="toggle">
                      <span onClick={() => mutations.enable.mutate(account.id)}><Power size={16} /></span>
                    </Tooltip>
                  ),
                  <Tooltip title="Delete" key="delete">
                    <span
                      onClick={() => {
                        Modal.confirm({
                          title: 'Delete account?',
                          onOk: () => mutations.remove.mutate(account.id),
                        });
                      }}
                    >
                      <Trash2 size={16} style={{ color: '#ff4d4f' }} />
                    </span>
                  </Tooltip>,
                ]}
              >
                <Card.Meta
                  title={account.name}
                  description={
                    <>
                      <Typography.Text type="secondary">
                        {PLATFORMS.find((p) => p.value === account.platform)?.label || account.platform}
                      </Typography.Text>
                      {account.profileUrl && (
                        <div>
                          <Typography.Link href={account.profileUrl} target="_blank">
                            {account.profileUrl}
                          </Typography.Link>
                        </div>
                      )}
                      {account.postingMode === 'webhook' && account.webhookUrl && (
                        <Typography.Paragraph type="secondary" ellipsis style={{ marginTop: 8, marginBottom: 0 }}>
                          {account.webhookUrl}
                        </Typography.Paragraph>
                      )}
                      <Typography.Paragraph type="secondary" style={{ marginTop: 8, marginBottom: 0 }}>
                        {account.postingMode === 'webhook' ? 'Webhook' : 'Manual'}
                        {account.postingMode === 'webhook' && account.webhookAuthType === 'basic' ? ' · Basic auth' : ''}
                        {' · '}
                        {account.enabled ? 'Enabled' : 'Disabled'}
                      </Typography.Paragraph>
                    </>
                  }
                />
              </Card>
            </Col>
          ))}
        </Row>
      )}

      <Modal
        title={editing ? 'Edit Account' : 'Add Account'}
        open={modalOpen}
        onCancel={() => setModalOpen(false)}
        onOk={() => form.submit()}
      >
        <Form form={form} layout="vertical" onFinish={handleSave}>
          <Form.Item name="platform" label="Platform" rules={[{ required: true }]}>
            <Select options={PLATFORMS} disabled={!!editing} />
          </Form.Item>
          <Form.Item name="name" label="Name" rules={[{ required: true }]}>
            <Input />
          </Form.Item>
          <Form.Item name="profileUrl" label="Profile URL">
            <Input placeholder="https://instagram.com/example" />
          </Form.Item>
          <Form.Item name="postingMode" label="Action type" rules={[{ required: true }]}>
            <Radio.Group>
              <Radio.Button value="manual">Manual</Radio.Button>
              <Radio.Button value="webhook">Webhook</Radio.Button>
            </Radio.Group>
          </Form.Item>
          {postingMode === 'webhook' && (
            <>
              <Form.Item
                name="webhookUrl"
                label="Webhook URL"
                rules={[{ required: true, message: 'Webhook URL is required' }]}
              >
                <Input placeholder="https://n8n.example.com/webhook/post" />
              </Form.Item>
              <Form.Item name="webhookAuthType" label="Credentials" rules={[{ required: true }]}>
                <Radio.Group>
                  <Radio.Button value="none">None</Radio.Button>
                  <Radio.Button value="basic">Basic</Radio.Button>
                </Radio.Group>
              </Form.Item>
              {webhookAuthType === 'basic' && (
                <>
                  <Form.Item
                    name="webhookUsername"
                    label="Username"
                    rules={[{ required: true, message: 'Username is required' }]}
                  >
                    <Input autoComplete="off" />
                  </Form.Item>
                  <Form.Item
                    name="webhookPassword"
                    label="Password"
                    rules={editing?.webhookHasPassword ? [] : [{ required: true, message: 'Password is required' }]}
                  >
                    <Input.Password
                      placeholder={editing?.webhookHasPassword ? 'Leave blank to keep the current password' : undefined}
                      autoComplete="new-password"
                    />
                  </Form.Item>
                </>
              )}
            </>
          )}
        </Form>
      </Modal>
    </div>
  );
}
