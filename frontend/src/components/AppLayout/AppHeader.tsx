import { Button, Layout, Space } from 'antd';
import { LogOut } from 'lucide-react';
import { useAuth } from '../../app/providers/AuthProvider';
import { useNavigate } from 'react-router-dom';

const { Header } = Layout;

export function AppHeader() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  return (
    <Header style={{ background: '#fff', padding: '0 24px', borderBottom: '1px solid #f0f0f0', display: 'flex', alignItems: 'center', justifyContent: 'flex-end' }}>
      <Space>
        <span>{user?.displayName || user?.email}</span>
        <Button type="text" icon={<LogOut size={16} />} onClick={handleLogout}>Logout</Button>
      </Space>
    </Header>
  );
}

export default AppHeader;
