// src/constants/api.js
import Config from 'react-native-config';

export const API_BASE_URL = Config.API_BASE_URL || 'http://192.168.1.100:8000';
export const APP_VERSION  = Config.APP_VERSION  || '1.0.0';
export const API_TIMEOUT  = 15000; // ms

// Endpoint paths (no leading slash — appended to API_BASE_URL in client.js)
export const ENDPOINTS = {
  HEALTH:          '/api/health',
  PRINTER_STATUS:  '/api/printer/status',
  PRINTER_JOB:     (jobId) => `/api/printer/job-status/${jobId}`,
  DOCUMENTS_UPLOAD:'/api/documents/upload',
  DOCUMENTS_DELETE:(id)    => `/api/documents/${id}`,
  ORDERS_CREATE:   '/api/orders/create',
  ORDERS_STATUS:   (id)    => `/api/orders/${id}/status`,
  ORDERS_CANCEL:   (id)    => `/api/orders/${id}`,
  PAYMENTS_CREATE: '/api/payments/create',
  OTP_GET:         (orderId) => `/api/otp/${orderId}`,
};
