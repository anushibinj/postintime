import { createContext, useContext, useState, useEffect, useCallback, type ReactNode } from 'react';
import {
  getToken,
  clearToken,
  isTokenExpired,
  getTokenExpiryMs,
  onSessionExpired,
} from '../../api/client';
import { queryClient } from './AppQueryProvider';
import type { AuthResponse } from '../../api/auth';

interface AuthContextValue {
  user: AuthResponse | null;
  isAuthenticated: boolean;
  setUser: (user: AuthResponse | null) => void;
  logout: () => void;
}

const AuthContext = createContext<AuthContextValue | null>(null);

function userFromToken(token: string): AuthResponse | null {
  try {
    const payload = JSON.parse(atob(token.split('.')[1])) as { sub?: string; email?: string };
    return {
      token,
      userId: payload.sub || '',
      email: payload.email || '',
      displayName: payload.email || '',
    };
  } catch {
    return null;
  }
}

function readStoredUser(): AuthResponse | null {
  const token = getToken();
  if (!token || isTokenExpired(token)) {
    clearToken();
    return null;
  }
  return userFromToken(token);
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUserState] = useState<AuthResponse | null>(() => readStoredUser());

  const clearAuthState = useCallback(() => {
    clearToken();
    setUserState(null);
    queryClient.clear();
  }, []);

  const setUser = useCallback((next: AuthResponse | null) => {
    if (!next) {
      clearAuthState();
      return;
    }
    setUserState(next);
  }, [clearAuthState]);

  const logout = useCallback(() => {
    clearAuthState();
  }, [clearAuthState]);

  useEffect(() => {
    return onSessionExpired(() => {
      setUserState(null);
      queryClient.clear();
    });
  }, []);

  useEffect(() => {
    const token = user?.token || getToken();
    if (!token) {
      return;
    }
    if (isTokenExpired(token)) {
      clearAuthState();
      return;
    }
    const expiryMs = getTokenExpiryMs(token);
    if (expiryMs == null) {
      return;
    }
    const timeout = window.setTimeout(() => {
      clearAuthState();
    }, Math.max(0, expiryMs - Date.now()));
    return () => window.clearTimeout(timeout);
  }, [user?.token, clearAuthState]);

  return (
    <AuthContext.Provider value={{ user, isAuthenticated: !!user, setUser, logout }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within AuthProvider');
  return ctx;
}
