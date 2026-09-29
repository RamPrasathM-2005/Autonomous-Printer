// src/utils/format.js
// Pure formatting utilities — no side effects, no imports from React

/**
 * Formats bytes into a human-readable file size string.
 * @param {number} bytes
 * @returns {string} e.g. "3.2 MB", "512 KB"
 */
export function formatFileSize(bytes) {
  if (bytes === 0) return '0 B';
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  return `${(bytes / (1024 * 1024 * 1024)).toFixed(1)} GB`;
}

/**
 * Formats a number as Indian Rupee string.
 * @param {number} amount - Amount in rupees
 * @returns {string} e.g. "₹245.00"
 */
export function formatCurrency(amount) {
  return `₹${Number(amount).toFixed(2)}`;
}

/**
 * Formats seconds into MM:SS string.
 * @param {number} totalSeconds
 * @returns {string} e.g. "04:32"
 */
export function formatCountdown(totalSeconds) {
  const mins = Math.floor(totalSeconds / 60);
  const secs = totalSeconds % 60;
  return `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
}

/**
 * Truncates a filename to a maximum length, preserving extension.
 * @param {string} name
 * @param {number} maxLength
 * @returns {string}
 */
export function truncateFileName(name, maxLength = 28) {
  if (name.length <= maxLength) return name;
  const ext = name.lastIndexOf('.') > 0 ? name.slice(name.lastIndexOf('.')) : '';
  const base = name.slice(0, maxLength - ext.length - 3);
  return `${base}...${ext}`;
}

/**
 * Returns time remaining in seconds from an ISO8601 expiry string.
 * @param {string} expiresAt - ISO8601 timestamp
 * @returns {number} seconds remaining (min 0)
 */
export function secondsUntil(expiresAt) {
  return Math.max(0, Math.floor((new Date(expiresAt) - Date.now()) / 1000));
}
