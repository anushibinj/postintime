import { Button, Form, Input, Modal, Space, Switch, Table, Typography, message } from 'antd';
import { Plus } from 'lucide-react';
import { useState } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { createChannel, updateChannel, deleteChannel } from '../../api/channels';
import { useChannels } from '../../hooks/useChannels';
import { useNavigate } from 'react-router-dom';
import type { Channel } from '../../types';

export function ChannelsPage() {
  const { data: channels = [], isLoading } = useChannels();
  const [modalOpen, setModalOpen] = useState(false);
  const [editing, setEditing] = useState<Channel | null>(null);
  const [form] = Form.useForm();
  const queryClient = useQueryClient();
  const navigate = useNavigate();

  const saveMutation = useMutation({
    mutationFn: async (values: { name: string; slug: string; description?: string; enabled?: boolean }) => {
      if (editing) {
        return updateChannel(editing.id, values);
      }
      return createChannel(values);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['channels'] });
      setModalOpen(false);
      setEditing(null);
      form.resetFields();
      message.success('Channel saved');
    },
    onError: () => message.error('Failed to save channel'),
  });

  const deleteMutation = useMutation({
    mutationFn: deleteChannel,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['channels'] });
      message.success('Channel deleted');
    },
  });

  const openCreate = () => {
    setEditing(null);
    form.resetFields();
    setModalOpen(true);
  };

  const openEdit = (channel: Channel) => {
    setEditing(channel);
    form.setFieldsValue(channel);
    setModalOpen(true);
  };

  return (
    <div>
      <Space style={{ width: '100%', justifyContent: 'space-between', marginBottom: 24 }}>
        <Typography.Title level={2} style={{ margin: 0 }}>Channels</Typography.Title>
        <Button type="primary" icon={<Plus size={16} />} onClick={openCreate}>New Channel</Button>
      </Space>

      <Table
        loading={isLoading}
        dataSource={channels}
        rowKey="id"
        columns={[
          { title: 'Name', dataIndex: 'name', key: 'name' },
          { title: 'Slug', dataIndex: 'slug', key: 'slug' },
          { title: 'Posts', dataIndex: 'postCount', key: 'postCount' },
          { title: 'Social Accounts', dataIndex: 'socialAccountCount', key: 'socialAccountCount' },
          {
            title: 'Enabled',
            dataIndex: 'enabled',
            key: 'enabled',
            render: (enabled: boolean) => (enabled ? 'Yes' : 'No'),
          },
          {
            title: 'Actions',
            key: 'actions',
            render: (_, record) => (
              <Space>
                <Button size="small" onClick={() => navigate(`/channels/${record.id}`)}>View</Button>
                <Button size="small" onClick={() => openEdit(record)}>Edit</Button>
                <Button size="small" danger onClick={() => {
                  Modal.confirm({
                    title: 'Delete channel?',
                    content: 'This will delete all posts and social accounts in this channel.',
                    onOk: () => deleteMutation.mutate(record.id),
                  });
                }}>Delete</Button>
              </Space>
            ),
          },
        ]}
      />

      <Modal
        title={editing ? 'Edit Channel' : 'Create Channel'}
        open={modalOpen}
        onCancel={() => setModalOpen(false)}
        onOk={() => form.submit()}
        confirmLoading={saveMutation.isPending}
      >
        <Form form={form} layout="vertical" onFinish={(v) => saveMutation.mutate(v)}>
          <Form.Item name="name" label="Name" rules={[{ required: true }]}>
            <Input />
          </Form.Item>
          <Form.Item name="slug" label="Slug" rules={[{ required: true, pattern: /^[a-z0-9]+(?:-[a-z0-9]+)*$/ }]}>
            <Input disabled={!!editing} placeholder="tech" />
          </Form.Item>
          <Form.Item name="description" label="Description">
            <Input.TextArea rows={3} />
          </Form.Item>
          {editing && (
            <Form.Item name="enabled" label="Enabled" valuePropName="checked">
              <Switch />
            </Form.Item>
          )}
        </Form>
      </Modal>
    </div>
  );
}
