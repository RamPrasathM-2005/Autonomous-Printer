// src/services/api/documents.js
import { apiClient } from './client';
import { ENDPOINTS } from '../../constants/api';

export const documentsApi = {
  /**
   * Uploads a single file to the backend with progress tracking.
   * @param {{ uri: string, type: string, name: string }} file
   * @param {(percent: number) => void} onProgress - Called with 0-100
   * @param {AbortSignal} signal - Cancellation signal
   * @returns {Promise<{ documentId, fileName, pageCount, thumbnailUrl, mimeType }>}
   */
  upload: (file, onProgress, signal) => {
    const formData = new FormData();
    formData.append('file', {
      uri:  file.uri,
      type: file.type,
      name: file.name,
    });

    return apiClient.post(ENDPOINTS.DOCUMENTS_UPLOAD, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
      signal,
      onUploadProgress: (progressEvent) => {
        if (progressEvent.total) {
          const percent = Math.round(
            (progressEvent.loaded / progressEvent.total) * 100
          );
          onProgress(percent);
        }
      },
    });
  },

  /**
   * Deletes an uploaded document from the backend.
   * @param {string} documentId
   * @returns {Promise<void>}
   */
  delete: (documentId) => apiClient.delete(ENDPOINTS.DOCUMENTS_DELETE(documentId)),
};
