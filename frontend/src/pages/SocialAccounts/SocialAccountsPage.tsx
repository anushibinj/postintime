import { Button, Card, Form, Input, Modal, Select, Space, Typography, message } from 'antd';
import { Plus } from 'lucide-react';
import { useParams } from 'react-router-dom';
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
      <Space style={{ width: '100%', justifyContent: 'space-between', marginBottom: 24 }}>
        <Typography.Title level={2} style={{ margin: 0 }}>Social Accounts</Typography.Title>
        <Button type="primary" icon={<Plus size={16} />} onClick={openCreate}>Add Account</Button>
      </Space>

      {isLoading ? <Typography.Text>Loading...</Typography.Text> : accounts.map((account) => (
        <Card key={account.id} style={{ marginBottom: 16 }}>
          <Space direction="vertical">
            <Typography.Text strong>{PLATFORMS.find((p) => p.value === account.platform)?.label || account.platform}</Typography.Text>
            <Typography.Text>{account.name}</Typography.Text>
            {account.profileUrl && <Typography.Link href={account.profileUrl} target="_blank">{account.profileUrl}</Typography.Link>}
            <Typography.Text type="secondary">Manual · {account.enabled ? 'Enabled' : 'Disabled'}</Typography.Text>
            <Space>
              <Button size="small" onClick={() => openEdit(account)}>Edit</Button>
              {account.enabled ? (
                <Button size="small" onClick={() => mutations.disable.mutate(account.id)}>Disable</Button>
              ) : (
                <Button size="small" onClick={() => mutations.enable.mutate(account.id)}>Enable</Button>
              )}
              <Button size="small" danger onClick={() => {
                Modal.confirm({
                  title: 'Delete account?',
                  onOk: () => mutations.remove.mutate(account.id),
                });
              }}>Delete</Button>
            </Space>
          </Space>
        </Card>
      ))}

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
