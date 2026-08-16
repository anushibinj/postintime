import { createContext, useContext, useState, type ReactNode } from 'react';

interface ChannelContextValue {
  selectedChannelId: string | null;
  setSelectedChannelId: (id: string | null) => void;
}

const ChannelContext = createContext<ChannelContextValue | null>(null);

export function ChannelProvider({ children }: { children: ReactNode }) {
  const [selectedChannelId, setSelectedChannelId] = useState<string | null>(null);
  return (
    <ChannelContext.Provider value={{ selectedChannelId, setSelectedChannelId }}>
      {children}
    </ChannelContext.Provider>
  );
}

export function useChannelContext() {
  const ctx = useContext(ChannelContext);
  if (!ctx) throw new Error('useChannelContext must be used within ChannelProvider');
  return ctx;
}
