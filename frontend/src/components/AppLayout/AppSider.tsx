import { Layout, Menu, Typography } from 'antd';
import { Radio, Settings } from 'lucide-react';
import { Link, useLocation } from 'react-router-dom';

const { Sider } = Layout;

export function AppSider() {
  const location = useLocation();
  const selected = location.pathname.startsWith('/settings') ? 'settings' : 'channels';

  return (
    <Sider theme="light" width={220} style={{ borderRight: '1px solid #f0f0f0' }}>
      <div style={{ padding: '16px 24px' }}>
        <Typography.Title level={4} style={{ margin: 0 }}>PostInTime</Typography.Title>
      </div>
      <Menu
        mode="inline"
        selectedKeys={[selected]}
        items={[
          { key: 'channels', icon: <Radio size={16} />, label: <Link to="/channels">Channels</Link> },
          { key: 'settings', icon: <Settings size={16} />, label: <Link to="/settings">Settings</Link> },
        ]}
      />
    </Sider>
  );
}
