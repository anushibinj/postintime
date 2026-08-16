import { Typography } from 'antd';
import { useAuth } from '../../app/providers/AuthProvider';

export function SettingsPage() {
  const { user } = useAuth();
  return (
    <div>
      <Typography.Title level={2}>Settings</Typography.Title>
      <Typography.Paragraph>Email: {user?.email}</Typography.Paragraph>
    </div>
  );
}
