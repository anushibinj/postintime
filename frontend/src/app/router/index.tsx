import { lazy, Suspense } from 'react';
import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import { ConfigProvider, App as AntApp } from 'antd';
import { AuthProvider } from '../providers/AuthProvider';
import { AppQueryProvider } from '../providers/AppQueryProvider';
import { PageLoader } from '../../components/PageLoader/PageLoader';

const ProtectedRoute = lazy(() => import('./ProtectedRoute'));
const LoginPage = lazy(() => import('../../pages/Auth/LoginPage'));
const RegisterPage = lazy(() => import('../../pages/Auth/RegisterPage'));
const AppLayout = lazy(() => import('../../components/AppLayout/AppLayout'));
const ChannelsPage = lazy(() => import('../../pages/Channels/ChannelsPage'));
const ChannelDetailPage = lazy(() => import('../../pages/Channels/ChannelDetailPage'));
const PostListPage = lazy(() => import('../../pages/Posts/PostListPage'));
const PostFormPage = lazy(() => import('../../pages/Posts/PostFormPage'));
const PostDetailPage = lazy(() => import('../../pages/Posts/PostDetailPage'));
const SocialAccountsPage = lazy(() => import('../../pages/SocialAccounts/SocialAccountsPage'));
const SettingsPage = lazy(() => import('../../pages/Settings/SettingsPage'));

export function AppRouter() {
  return (
    <ConfigProvider
      theme={{
        token: {
          colorPrimary: '#1677ff',
          borderRadius: 8,
        },
      }}
    >
      <AntApp>
        <AppQueryProvider>
          <AuthProvider>
            <BrowserRouter>
              <Suspense fallback={<PageLoader />}>
                <Routes>
                  <Route path="/login" element={<LoginPage />} />
                  <Route path="/register" element={<RegisterPage />} />
                  <Route element={<ProtectedRoute />}>
                    <Route element={<AppLayout />}>
                      <Route index element={<Navigate to="/channels" replace />} />
                      <Route path="channels" element={<ChannelsPage />} />
                      <Route path="channels/:channelId" element={<ChannelDetailPage />} />
                      <Route path="channels/:channelId/posts" element={<PostListPage />} />
                      <Route path="channels/:channelId/posts/new" element={<PostFormPage />} />
                      <Route path="channels/:channelId/posts/:postId" element={<PostDetailPage />} />
                      <Route path="channels/:channelId/posts/:postId/edit" element={<PostFormPage />} />
                      <Route path="channels/:channelId/social-accounts" element={<SocialAccountsPage />} />
                      <Route path="settings" element={<SettingsPage />} />
                    </Route>
                  </Route>
                  <Route path="*" element={<Navigate to="/channels" replace />} />
                </Routes>
              </Suspense>
            </BrowserRouter>
          </AuthProvider>
        </AppQueryProvider>
      </AntApp>
    </ConfigProvider>
  );
}
