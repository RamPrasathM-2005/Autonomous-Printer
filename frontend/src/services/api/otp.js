// src/services/api/otp.js
import { apiClient } from './client';
import { ENDPOINTS } from '../../constants/api';

export const otpApi = {
  /**
   * Fetches the OTP for a confirmed and paid order.
   * @param {string} orderId
   * @returns {Promise<{ otp: string, expiresAt: string }>}
   */
  getOTP: (orderId) => apiClient.get(ENDPOINTS.OTP_GET(orderId)),
};
