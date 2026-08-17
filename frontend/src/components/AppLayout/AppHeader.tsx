import { Button, Layout, Space, Tooltip } from 'antd';
import { LogOut, PanelLeft, PanelLeftClose } from 'lucide-react';
import { useAuth } from '../../app/providers/AuthProvider';
import { ChannelSwitcher } from '../ChannelSwitcher/ChannelSwitcher';
import { useNavigate } from 'react-router-dom';

const { Header } = Layout;

export function AppHeader({ collapsed, onToggleSider }: { collapsed: boolean; onToggleSider: () => void }) {
  const { user, logout } = useAuth();
  const navigate = useNavigate();

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  return (
    <Header style={{ background: '#fff', padding: '0 24px', borderBottom: '1px solid #f0f0f0', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
      <Space>
        <Tooltip title={collapsed ? 'Expand sidebar' : 'Collapse sidebar'}>
          <Button
            type="text"
            aria-label={collapsed ? 'Expand sidebar' : 'Collapse sidebar'}
            icon={collapsed ? <PanelLeft size={16} /> : <PanelLeftClose size={16} />}
            onClick={onToggleSider}
          />
        </Tooltip>
        <ChannelSwitcher />
      </Space>
      <Space>
        <span>{user?.displayName || user?.email}</span>
        <Button type="text" icon={<LogOut size={16} />} onClick={handleLogout}>Logout</Button>
      </Space>
    </Header>
  );
}
