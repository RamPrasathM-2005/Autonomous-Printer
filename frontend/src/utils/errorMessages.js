// src/utils/errorMessages.js
// Maps backend error codes to user-friendly strings.
// Never show raw backend messages or library errors directly in the UI.

const ERROR_MESSAGES = {
  NETWORK_UNAVAILABLE:   'No internet connection. Please check your network.',
  TIMEOUT:               'Request timed out. Please try again.',
  CANCELLED:             'Request was cancelled.',
  UNSUPPORTED_FILE_TYPE: 'Unsupported file type. Use PDF, DOCX, PPTX, PNG, or JPG.',
  FILE_TOO_LARGE:        'File exceeds the 20 MB size limit.',
  TOO_MANY_FILES:        'You can upload a maximum of 10 files per session.',
  DUPLICATE_FILE:        'This file has already been selected.',
  UPLOAD_FAILED:         'Upload failed. Please try again.',
  PRINTER_OFFLINE:       'The printer is currently offline.',
  PRINTER_UNAVAILABLE:   'The printer is unavailable. Please try again later.',
  PAPER_EMPTY:           'The printer is out of paper. Please contact the desk.',
  ORDER_CREATION_FAILED: 'Could not create order. Please try again.',
  PAYMENT_FAILED:        'Payment failed. Please retry or use a different method.',
  OTP_EXPIRED:           'OTP has expired. Your order has been cancelled.',
  OTP_NOT_FOUND:         'OTP not found. Please contact support.',
  JOB_FAILED:            'Printing failed. A refund will be processed.',
  DOCUMENT_NOT_FOUND:    'Document not found. Please re-upload.',
  INVALID_PAGE_RANGE:    'Invalid page range. Please check and try again.',
  DOCUMENT_EXPIRED:      'Your upload has expired. Please upload again.',
  FORBIDDEN:             'You do not have access to this item.',
  RATE_LIMITED:          'Too many requests. Please try again in a moment.',
  UNKNOWN_ERROR:         'Something went wrong. Please try again.',
};

/**
 * Returns a human-readable error message for a given error code.
 * @param {string} code - Backend error code or interceptor-generated code
 * @returns {string}
 */
export function getErrorMessage(code) {
  return ERROR_MESSAGES[code] ?? ERROR_MESSAGES.UNKNOWN_ERROR;
}

export default ERROR_MESSAGES;
