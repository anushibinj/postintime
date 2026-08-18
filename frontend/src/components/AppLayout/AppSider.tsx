import { Button, Layout, Menu, Tooltip, Typography } from 'antd';
import { PanelLeft, PanelLeftClose, Radio, Settings } from 'lucide-react';
import { Link, useLocation } from 'react-router-dom';

const { Sider } = Layout;

export function AppSider({ collapsed, onToggle }: { collapsed: boolean; onToggle: () => void }) {
  const location = useLocation();
  const selected = location.pathname.startsWith('/settings') ? 'settings' : 'channels';
  const toggleLabel = collapsed ? 'Expand sidebar' : 'Collapse sidebar';

  return (
    <Sider
      theme="light"
      width={220}
      collapsedWidth={64}
      collapsed={collapsed}
      trigger={null}
      style={{ borderRight: '1px solid #f0f0f0' }}
    >
      <div style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
        <div style={{ padding: collapsed ? '16px 0' : '16px 24px', textAlign: collapsed ? 'center' : 'left' }}>
          <Typography.Title level={4} style={{ margin: 0 }}>
            {collapsed ? 'P' : 'PostInTime'}
          </Typography.Title>
        </div>
        <Menu
          mode="inline"
          selectedKeys={[selected]}
          style={{ flex: 1, borderInlineEnd: 'none' }}
          items={[
            { key: 'channels', icon: <Radio size={16} />, label: <Link to="/channels">Channels</Link> },
            { key: 'settings', icon: <Settings size={16} />, label: <Link to="/settings">Settings</Link> },
          ]}
        />
        <div style={{ padding: 8, borderTop: '1px solid #f0f0f0', textAlign: collapsed ? 'center' : 'right' }}>
          <Tooltip title={toggleLabel} placement="right">
            <Button
              type="text"
              aria-label={toggleLabel}
              icon={collapsed ? <PanelLeft size={16} /> : <PanelLeftClose size={16} />}
              onClick={onToggle}
            />
          </Tooltip>
        </div>
      </div>
    </Sider>
  );
}
