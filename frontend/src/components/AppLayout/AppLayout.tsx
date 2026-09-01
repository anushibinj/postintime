import { Layout } from 'antd';
import { lazy, Suspense, useState } from 'react';
import { Outlet } from 'react-router-dom';
import { PageLoader } from '../PageLoader/PageLoader';

const AppHeader = lazy(() => import('./AppHeader'));
const AppSider = lazy(() => import('./AppSider'));

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
      <Suspense fallback={<PageLoader />}>
        <AppSider collapsed={collapsed} onToggle={handleToggle} />
      </Suspense>
      <Layout style={{ overflow: 'hidden' }}>
        <Suspense fallback={<PageLoader />}>
          <AppHeader />
        </Suspense>
        <Content style={{ padding: 24, background: '#f5f5f5', overflow: 'auto' }}>
          <Suspense fallback={<PageLoader />}>
            <Outlet />
          </Suspense>
        </Content>
      </Layout>
    </Layout>
  );
}

export default AppLayout;
