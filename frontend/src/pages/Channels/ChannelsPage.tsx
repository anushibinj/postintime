import { Button, Card, Col, Empty, Form, Input, Modal, Row, Space, Switch, Tag, Typography, message } from 'antd';
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

      {isLoading ? (
        <Typography.Text>Loading...</Typography.Text>
      ) : channels.length === 0 ? (
        <Empty description="No channels yet">
          <Button type="primary" onClick={openCreate}>Create Channel</Button>
        </Empty>
      ) : (
        <Row gutter={[16, 16]}>
          {channels.map((channel) => (
            <Col key={channel.id} xs={24} sm={12} lg={8}>
              <Card
                styles={{ body: { display: 'flex', flexDirection: 'column', minHeight: 180 } }}
              >
                <div style={{ flex: 1 }}>
                  <Space style={{ width: '100%', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                    <Typography.Title level={4} style={{ margin: 0 }}>{channel.name}</Typography.Title>
                    <Tag color={channel.enabled ? 'green' : 'default'}>
                      {channel.enabled ? 'Enabled' : 'Disabled'}
                    </Tag>
                  </Space>
                  <Typography.Text type="secondary">/{channel.slug}</Typography.Text>
                  {channel.description && (
                    <Typography.Paragraph type="secondary" ellipsis={{ rows: 2 }} style={{ marginTop: 8, marginBottom: 0 }}>
                      {channel.description}
                    </Typography.Paragraph>
                  )}
                  <Typography.Paragraph type="secondary" style={{ marginTop: 12, marginBottom: 0 }}>
                    {channel.postCount} posts · {channel.socialAccountCount} social accounts
                  </Typography.Paragraph>
                </div>
                <Space style={{ marginTop: 16 }}>
                  <Button size="small" onClick={() => navigate(`/channels/${channel.id}`)}>View</Button>
                  <Button size="small" onClick={() => openEdit(channel)}>Edit</Button>
                  <Button size="small" danger onClick={() => {
                    Modal.confirm({
                      title: 'Delete channel?',
                      content: 'This will delete all posts and social accounts in this channel.',
                      onOk: () => deleteMutation.mutate(channel.id),
                    });
                  }}>Delete</Button>
                </Space>
              </Card>
            </Col>
          ))}
        </Row>
      )}

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
