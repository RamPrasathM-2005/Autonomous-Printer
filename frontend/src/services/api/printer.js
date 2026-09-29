// src/services/api/printer.js
import { apiClient } from './client';
import { ENDPOINTS } from '../../constants/api';

export const printerApi = {
  /**
   * Gets the current printer health status.
   * @returns {Promise<{ status, printerName, paperStatus, queueLength }>}
   */
  getStatus: () => apiClient.get(ENDPOINTS.PRINTER_STATUS),

  /**
   * Gets live job status for an active print job.
   * @param {string} jobId
   * @returns {Promise<{ jobStatus, queuePosition, printerName, progress }>}
   */
  getJobStatus: (jobId) => apiClient.get(ENDPOINTS.PRINTER_JOB(jobId)),
};
