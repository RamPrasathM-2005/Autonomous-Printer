// src/store/printStatusStore.js
// Persisted — job tracking must survive app kill
import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import { mmkvStorage } from '../services/storage/mmkv';

const initialState = {
  jobId:         null,
  status:        null,  // JobStatus enum string
  queuePosition: null,
  progress:      0,     // 0-100
};

const usePrintStatusStore = create(
  persist(
    (set) => ({
      ...initialState,

      setJob: (jobId) => set({ jobId }),

      updateStatus: (status, progress = 0, queuePosition = null) =>
        set({ status, progress, queuePosition }),

      reset: () => set(initialState),
    }),
    {
      name:    'print-status-store',
      storage: createJSONStorage(() => mmkvStorage),
    }
  )
);

export default usePrintStatusStore;
