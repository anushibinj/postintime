import { Layout, Menu, Typography } from 'antd';
import { LayoutDashboard, Radio, Settings } from 'lucide-react';
import { Link, useLocation } from 'react-router-dom';

const { Sider } = Layout;

export function AppSider() {
  const location = useLocation();
  const selected = location.pathname.startsWith('/channels') ? 'channels'
    : location.pathname.startsWith('/settings') ? 'settings' : 'dashboard';

  return (
    <Sider theme="light" width={220} style={{ borderRight: '1px solid #f0f0f0' }}>
      <div style={{ padding: '16px 24px' }}>
        <Typography.Title level={4} style={{ margin: 0 }}>PostInTime</Typography.Title>
      </div>
      <Menu
        mode="inline"
        selectedKeys={[selected]}
        items={[
          { key: 'dashboard', icon: <LayoutDashboard size={16} />, label: <Link to="/">Dashboard</Link> },
          { key: 'channels', icon: <Radio size={16} />, label: <Link to="/channels">Channels</Link> },
          { key: 'settings', icon: <Settings size={16} />, label: <Link to="/settings">Settings</Link> },
        ]}
      />
    </Sider>
  );
}
