import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import { ConfigProvider, App as AntApp } from 'antd';
import { AuthProvider } from '../providers/AuthProvider';
import { AppQueryProvider } from '../providers/AppQueryProvider';
import { ProtectedRoute } from './ProtectedRoute';
import { LoginPage } from '../../pages/Auth/LoginPage';
import { RegisterPage } from '../../pages/Auth/RegisterPage';
import { AppLayout } from '../../components/AppLayout/AppLayout';
import { ChannelsPage } from '../../pages/Channels/ChannelsPage';
import { ChannelDetailPage } from '../../pages/Channels/ChannelDetailPage';
import { PostListPage } from '../../pages/Posts/PostListPage';
import { PostFormPage } from '../../pages/Posts/PostFormPage';
import { PostDetailPage } from '../../pages/Posts/PostDetailPage';
import { SocialAccountsPage } from '../../pages/SocialAccounts/SocialAccountsPage';
import { SettingsPage } from '../../pages/Settings/SettingsPage';

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
            </BrowserRouter>
          </AuthProvider>
        </AppQueryProvider>
      </AntApp>
    </ConfigProvider>
  );
}
