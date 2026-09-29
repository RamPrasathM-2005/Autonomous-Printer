// src/store/printerStatusStore.js
import { create } from 'zustand';

const useprinterStatusStore = create((set) => ({
  status:       'unknown', // 'online' | 'offline' | 'busy' | 'unknown'
  printerName:  null,
  paperStatus:  'unknown', // 'ok' | 'low' | 'empty' | 'unknown'
  queueLength:  0,

  update: (data) => set((state) => ({ ...state, ...data })),
  reset:  () => set({ status: 'unknown', printerName: null, paperStatus: 'unknown', queueLength: 0 }),
}));

export default useprinterStatusStore;
