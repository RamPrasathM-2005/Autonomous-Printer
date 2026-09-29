// src/store/otpStore.js
// Persisted — OTP must survive app kill/restart
import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import { mmkvStorage } from '../services/storage/mmkv';

const initialState = {
  otp:       null,   // 6-digit string
  expiresAt: null,   // ISO8601
};

const useOTPStore = create(
  persist(
    (set) => ({
      ...initialState,

      setOTP: (otp, expiresAt) => set({ otp, expiresAt }),
      clearOTP: () => set({ otp: null, expiresAt: null }),
      reset: () => set(initialState),
    }),
    {
      name:    'otp-store',
      storage: createJSONStorage(() => mmkvStorage),
    }
  )
);

export default useOTPStore;
