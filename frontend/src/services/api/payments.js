// src/services/api/payments.js
import { apiClient } from './client';
import { ENDPOINTS } from '../../constants/api';

export const paymentsApi = {
  /**
   * Creates a Razorpay payment order on the backend.
   * @param {string} orderId
   * @returns {Promise<{ razorpayOrderId, keyId, amount, currency }>}
   */
  create: (orderId) => apiClient.post(ENDPOINTS.PAYMENTS_CREATE, { orderId }),
};
