// src/constants/files.js
// File validation rules — must match backend limits

export const MAX_FILE_SIZE_MB    = 20;
export const MAX_FILE_SIZE_BYTES = MAX_FILE_SIZE_MB * 1024 * 1024;
export const MAX_FILE_COUNT      = 10;

// Allowed MIME types for document picker
export const ALLOWED_MIME_TYPES = [
  'application/pdf',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',   // .docx
  'application/vnd.openxmlformats-officedocument.presentationml.presentation', // .pptx
  'image/png',
  'image/jpeg',
];

// Human-readable label for display in UI
export const ALLOWED_TYPES_LABEL = 'PDF, DOCX, PPTX, PNG, JPG';

// File extension → MIME map (used for fallback detection)
export const EXTENSION_MIME_MAP = {
  pdf:  'application/pdf',
  docx: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  pptx: 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  png:  'image/png',
  jpg:  'image/jpeg',
  jpeg: 'image/jpeg',
};
