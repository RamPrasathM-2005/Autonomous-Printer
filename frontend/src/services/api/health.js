// src/services/api/health.js
import { apiClient } from './client';
import { ENDPOINTS } from '../../constants/api';

/**
 * Checks if the backend is reachable and healthy.
 * @returns {Promise<{ status: string, version: string, timestamp: string }>}
 */
export const healthApi = {
  check: () => apiClient.get(ENDPOINTS.HEALTH),
};
