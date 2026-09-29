// src/store/appStore.js
import { create } from 'zustand';

const useAppStore = create((set) => ({
  // State
  printerStatus: 'unknown',   // 'online' | 'offline' | 'busy' | 'unknown'
  printerName:   null,
  paperStatus:   'unknown',   // 'ok' | 'low' | 'empty' | 'unknown'
  backendStatus: 'unknown',   // 'online' | 'offline' | 'unknown'
  isInitialized: false,

  // Actions
  setPrinterStatus: (status, name = null, paperStatus = 'unknown') =>
    set({ printerStatus: status, printerName: name, paperStatus }),

  setBackendStatus: (status) => set({ backendStatus: status }),

  setInitialized: () => set({ isInitialized: true }),
}));

export default useAppStore;
