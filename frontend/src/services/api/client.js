// src/services/api/client.js
// Axios instance with:
//   - NetInfo pre-flight check (rejects immediately if offline)
//   - Normalized error shape { code, message, status }
//   - Request timeout

import axios from 'axios';
import NetInfo from '@react-native-community/netinfo';
import { API_BASE_URL, API_TIMEOUT } from '../../constants/api';

export const apiClient = axios.create({
  baseURL: API_BASE_URL,
  timeout: API_TIMEOUT,
  headers: {
    'Content-Type': 'application/json',
    Accept: 'application/json',
  },
});

// ── Request interceptor ─────────────────────────────────────────────────────
// Reject before sending if the device has no internet.
apiClient.interceptors.request.use(async (config) => {
  const netState = await NetInfo.fetch();
  if (!netState.isConnected) {
    return Promise.reject({
      code: 'NETWORK_UNAVAILABLE',
      message: 'No internet connection.',
    });
  }
  return config;
});

// ── Response interceptor ────────────────────────────────────────────────────
// Normalize all errors into { code, message, status }.
apiClient.interceptors.response.use(
  (response) => response.data, // unwrap data so callers get the payload directly
  (error) => {
    if (axios.isCancel(error)) {
      return Promise.reject({ code: 'CANCELLED', message: 'Request cancelled.' });
    }
    if (error.code === 'ECONNABORTED') {
      return Promise.reject({ code: 'TIMEOUT', message: 'Request timed out.' });
    }
    const apiError = error.response?.data;
    return Promise.reject({
      code:    apiError?.error   ?? 'UNKNOWN_ERROR',
      message: apiError?.message ?? 'An unexpected error occurred.',
      status:  error.response?.status,
    });
  }
);
