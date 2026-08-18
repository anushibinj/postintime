import { Layout } from 'antd';
import { useState } from 'react';
import { Outlet } from 'react-router-dom';
import { AppHeader } from './AppHeader';
import { AppSider } from './AppSider';

const { Content } = Layout;
const SIDEBAR_COLLAPSED_KEY = 'postintime_sidebar_collapsed';

function readCollapsed(): boolean {
  return localStorage.getItem(SIDEBAR_COLLAPSED_KEY) === 'true';
}

export function AppLayout() {
  const [collapsed, setCollapsed] = useState(readCollapsed);

  const handleToggle = () => {
    setCollapsed((value) => {
      const next = !value;
      localStorage.setItem(SIDEBAR_COLLAPSED_KEY, String(next));
      return next;
    });
  };

  return (
    <Layout style={{ height: '100vh', overflow: 'hidden' }}>
      <AppSider collapsed={collapsed} onToggle={handleToggle} />
      <Layout style={{ overflow: 'hidden' }}>
        <AppHeader />
        <Content style={{ padding: 24, background: '#f5f5f5', overflow: 'auto' }}>
          <Outlet />
        </Content>
      </Layout>
    </Layout>
  );
}
