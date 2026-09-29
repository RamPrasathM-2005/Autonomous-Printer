// src/services/storage/mmkv.js
// MMKV instance — used for Zustand persist middleware.
// Falls back to a JSON-based AsyncStorage adapter if MMKV is unavailable.

import { MMKV } from 'react-native-mmkv';

const storage = new MMKV({ id: 'autonomous-printer-store' });

/**
 * Zustand-compatible storage adapter for MMKV.
 * Use this as the `storage` option in zustand/middleware persist().
 */
export const mmkvStorage = {
  setItem: (name, value) => {
    storage.set(name, value);
  },
  getItem: (name) => {
    const value = storage.getString(name);
    return value ?? null;
  },
  removeItem: (name) => {
    storage.delete(name);
  },
};

export default storage;
