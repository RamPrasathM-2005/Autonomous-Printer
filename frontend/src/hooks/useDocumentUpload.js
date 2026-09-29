// src/hooks/useDocumentUpload.js
// Manages the upload lifecycle for a batch of files.
// Uploads files sequentially, tracks per-file progress, handles cancellation.
import { useState, useRef, useCallback } from 'react';
import { documentsApi } from '../services/api/documents';
import useDocumentStore from '../store/documentStore';
import { validateFile, validateFileBatch } from '../utils/validation';

/**
 * @returns {{
 *   selectedFiles, addFiles, removeFile,
 *   uploadProgresses, uploadErrors,
 *   isUploading, uploadAll
 * }}
 */
export function useDocumentUpload() {
  const [selectedFiles, setSelectedFiles]     = useState([]);
  const [uploadProgresses, setUploadProgresses] = useState({});
  const [uploadErrors, setUploadErrors]       = useState({});
  const [isUploading, setIsUploading]         = useState(false);
  const abortControllers                      = useRef({});

  const addDocument  = useDocumentStore((s) => s.addDocument);
  const removeDocument = useDocumentStore((s) => s.removeDocument);

  // Add newly picked files after validation
  const addFiles = useCallback((incoming) => {
    const errors = {};
    const valid  = [];

    const batchCheck = validateFileBatch(selectedFiles, incoming);
    if (!batchCheck.valid) return { error: batchCheck.error };

    for (const file of incoming) {
      const result = validateFile(file);
      if (!result.valid) {
        errors[file.localId] = result.error;
      } else {
        valid.push(file);
      }
    }

    setSelectedFiles((prev) => [...prev, ...valid]);
    if (Object.keys(errors).length > 0) {
      setUploadErrors((prev) => ({ ...prev, ...errors }));
    }
    return { error: null };
  }, [selectedFiles]);

  // Remove a file from selected list; cancel upload if in progress
  const removeFile = useCallback((localId) => {
    setSelectedFiles((prev) => prev.filter((f) => f.localId !== localId));
    abortControllers.current[localId]?.abort();
    delete abortControllers.current[localId];
    setUploadProgresses((prev) => { const n = { ...prev }; delete n[localId]; return n; });
    setUploadErrors((prev) => { const n = { ...prev }; delete n[localId]; return n; });
  }, []);

  // Upload all selected files sequentially
  const uploadAll = useCallback(async () => {
    if (isUploading || selectedFiles.length === 0) return { success: false };
    setIsUploading(true);
    let allSucceeded = true;

    for (const file of selectedFiles) {
      const controller = new AbortController();
      abortControllers.current[file.localId] = controller;

      try {
        setUploadProgresses((prev) => ({ ...prev, [file.localId]: 0 }));
        const result = await documentsApi.upload(
          { uri: file.uri, type: file.type, name: file.name },
          (percent) =>
            setUploadProgresses((prev) => ({ ...prev, [file.localId]: percent })),
          controller.signal
        );
        addDocument({ ...result, status: 'uploaded' });
        setUploadProgresses((prev) => ({ ...prev, [file.localId]: 100 }));
      } catch (err) {
        if (err.code !== 'CANCELLED') {
          setUploadErrors((prev) => ({
            ...prev,
            [file.localId]: err.message || 'Upload failed.',
          }));
          allSucceeded = false;
        }
      } finally {
        delete abortControllers.current[file.localId];
      }
    }

    setIsUploading(false);
    return { success: allSucceeded };
  }, [isUploading, selectedFiles, addDocument]);

  return {
    selectedFiles,
    addFiles,
    removeFile,
    uploadProgresses,
    uploadErrors,
    isUploading,
    uploadAll,
  };
}
