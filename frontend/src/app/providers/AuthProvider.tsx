import { createContext, useContext, useState, useEffect, type ReactNode } from 'react';
import { getToken, clearToken } from '../../api/client';
import type { AuthResponse } from '../../api/auth';

interface AuthContextValue {
  user: AuthResponse | null;
  isAuthenticated: boolean;
  setUser: (user: AuthResponse | null) => void;
  logout: () => void;
}

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AuthResponse | null>(() => {
    const token = getToken();
    if (!token) return null;
    try {
      const payload = JSON.parse(atob(token.split('.')[1]));
      return {
        token,
        userId: payload.sub,
        email: payload.email,
        displayName: payload.email,
      };
    } catch {
      return null;
    }
  });

  useEffect(() => {
    if (!getToken()) {
      setUser(null);
    }
  }, []);

  const logout = () => {
    clearToken();
    setUser(null);
  };

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
