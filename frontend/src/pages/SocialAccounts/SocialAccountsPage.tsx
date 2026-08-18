import { Button, Card, Col, Form, Input, Modal, Row, Select, Space, Tooltip, Typography, message } from 'antd';
import { ArrowLeft, Pencil, Plus, Power, PowerOff, Trash2 } from 'lucide-react';
import { useNavigate, useParams } from 'react-router-dom';
import { useState } from 'react';
import { useSocialAccounts, useSocialAccountMutations } from '../../hooks/useSocialAccounts';
import type { Platform, SocialAccount } from '../../types';

const PLATFORMS: { value: Platform; label: string }[] = [
  { value: 'linkedin', label: 'LinkedIn' },
  { value: 'instagram', label: 'Instagram' },
  { value: 'whatsapp', label: 'WhatsApp' },
  { value: 'youtube', label: 'YouTube' },
  { value: 'x', label: 'X' },
  { value: 'facebook', label: 'Facebook' },
  { value: 'threads', label: 'Threads' },
];

export function SocialAccountsPage() {
  const { channelId } = useParams();
  const navigate = useNavigate();
  const { data: accounts = [], isLoading } = useSocialAccounts(channelId);
  const mutations = useSocialAccountMutations(channelId!);
  const [modalOpen, setModalOpen] = useState(false);
  const [editing, setEditing] = useState<SocialAccount | null>(null);
  const [form] = Form.useForm();

  const openCreate = () => {
    setEditing(null);
    form.resetFields();
    form.setFieldsValue({ postingMode: 'manual' });
    setModalOpen(true);
  };

  const openEdit = (account: SocialAccount) => {
    setEditing(account);
    form.setFieldsValue(account);
    setModalOpen(true);
  };

  const handleSave = async (values: { platform: Platform; name: string; profileUrl?: string }) => {
    try {
      if (editing) {
        await mutations.update.mutateAsync({ accountId: editing.id, data: values });
      } else {
        await mutations.create.mutateAsync(values);
      }
      setModalOpen(false);
      message.success('Account saved');
    } catch {
      message.error('Failed to save account');
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
                      <Typography.Paragraph type="secondary" style={{ marginTop: 8, marginBottom: 0 }}>
                        Manual · {account.enabled ? 'Enabled' : 'Disabled'}
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
        </Form>
      </Modal>
    </div>
  );
}
