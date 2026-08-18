import { Layout } from 'antd';
import { useState } from 'react';
import { Outlet } from 'react-router-dom';
import { AppHeader } from './AppHeader';
import { AppSider } from './AppSider';

const { Content } = Layout;

export function AppLayout() {
  const [collapsed, setCollapsed] = useState(false);

  return (
    <Layout style={{ height: '100vh', overflow: 'hidden' }}>
      <AppSider collapsed={collapsed} onToggle={() => setCollapsed((value) => !value)} />
      <Layout style={{ overflow: 'hidden' }}>
        <AppHeader />
        <Content style={{ padding: 24, background: '#f5f5f5', overflow: 'auto' }}>
          <Outlet />
        </Content>
      </Layout>
    </Layout>
  );
}
