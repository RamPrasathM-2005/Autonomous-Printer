// src/services/api/orders.js
import { apiClient } from './client';
import { ENDPOINTS } from '../../constants/api';

export const ordersApi = {
  /**
   * Creates an order with all document configurations.
   * @param {{ documents: Array }} data - CreateOrderRequest
   * @returns {Promise<{ orderId, items, subtotal, serviceFee, total, currency }>}
   */
  create: (data) => apiClient.post(ENDPOINTS.ORDERS_CREATE, data),

  /**
   * Polls order + job status.
   * @param {string} orderId
   * @returns {Promise<{ orderId, jobStatus, jobId }>}
   */
  getStatus: (orderId) => apiClient.get(ENDPOINTS.ORDERS_STATUS(orderId)),

  /**
   * Cancels an order that has not yet been paid.
   * @param {string} orderId
   * @returns {Promise<void>}
   */
  cancel: (orderId) => apiClient.delete(ENDPOINTS.ORDERS_CANCEL(orderId)),
};
