// src/utils/validation.js
import {
  ALLOWED_MIME_TYPES,
  MAX_FILE_SIZE_BYTES,
  MAX_FILE_COUNT,
  EXTENSION_MIME_MAP,
} from '../constants/files';

/**
 * Validates a single file picked by the document picker.
 * @param {{ name: string, type: string, size: number }} file
 * @returns {{ valid: boolean, error?: string }}
 */
export function validateFile(file) {
  // Try to detect type from extension if MIME is missing/generic
  const effectiveType = resolveType(file);

  if (!ALLOWED_MIME_TYPES.includes(effectiveType)) {
    return {
      valid: false,
      error: 'Unsupported file type. Use PDF, DOCX, PPTX, PNG, or JPG.',
    };
  }
  if (file.size > MAX_FILE_SIZE_BYTES) {
    const mb = (file.size / (1024 * 1024)).toFixed(1);
    return { valid: false, error: `File is ${mb} MB — exceeds the 20 MB limit.` };
  }
  return { valid: true };
}

/**
 * Validates a batch of selected files (count limit, duplicates).
 * @param {Array} existing - Already selected files
 * @param {Array} incoming - Newly picked files
 * @returns {{ valid: boolean, error?: string }}
 */
export function validateFileBatch(existing, incoming) {
  if (existing.length + incoming.length > MAX_FILE_COUNT) {
    return {
      valid: false,
      error: `Too many files. Maximum is ${MAX_FILE_COUNT} per session.`,
    };
  }
  const existingNames = new Set(existing.map((f) => f.name));
  const duplicate = incoming.find((f) => existingNames.has(f.name));
  if (duplicate) {
    return { valid: false, error: `"${duplicate.name}" has already been selected.` };
  }
  return { valid: true };
}

/**
 * Attempt to resolve MIME type from file extension when picker returns 
 * a generic or missing type.
 */
function resolveType(file) {
  if (file.type && ALLOWED_MIME_TYPES.includes(file.type)) return file.type;
  if (file.name) {
    const ext = file.name.split('.').pop()?.toLowerCase();
    if (ext && EXTENSION_MIME_MAP[ext]) return EXTENSION_MIME_MAP[ext];
  }
  return file.type || '';
}
