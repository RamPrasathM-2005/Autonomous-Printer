// src/store/orderStore.js
// Persisted with MMKV so app-kill recovery works after payment
import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import { mmkvStorage } from '../services/storage/mmkv';

const initialState = {
  orderId:      null,
  orderDetails: null, // { orderId, items, subtotal, serviceFee, total, currency }
};

const useOrderStore = create(
  persist(
    (set) => ({
      ...initialState,

      setOrder: (orderId, details) => set({ orderId, orderDetails: details }),

      reset: () => set(initialState),
    }),
    {
      name:    'order-store',
      storage: createJSONStorage(() => mmkvStorage),
    }
  )
);

export default useOrderStore;
