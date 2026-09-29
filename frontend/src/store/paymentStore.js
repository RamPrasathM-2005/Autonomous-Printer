// src/store/paymentStore.js
import { create } from 'zustand';

const initialState = {
  paymentInitiated:  false,
  razorpayOrderId:   null,
};

const usePaymentStore = create((set) => ({
  ...initialState,

  setPaymentInitiated: (razorpayOrderId) =>
    set({ paymentInitiated: true, razorpayOrderId }),

  reset: () => set(initialState),
}));

export default usePaymentStore;
