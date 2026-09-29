// src/hooks/useNetworkStatus.js
// Subscribes to NetInfo and exposes a simple isOnline boolean.
import { useState, useEffect } from 'react';
import NetInfo from '@react-native-community/netinfo';

/**
 * Returns { isOnline } — updates in real-time as connectivity changes.
 */
export function useNetworkStatus() {
  const [isOnline, setIsOnline] = useState(true);

  useEffect(() => {
    // Check immediately on mount
    NetInfo.fetch().then((state) => setIsOnline(!!state.isConnected));

    // Subscribe to changes
    const unsubscribe = NetInfo.addEventListener((state) => {
      setIsOnline(!!state.isConnected);
    });

    return unsubscribe;
  }, []);

  return { isOnline };
}
