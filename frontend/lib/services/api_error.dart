class ApiError implements Exception {
  final String message;
  const ApiError(this.message);

  factory ApiError.fromCode(String? code) => ApiError(switch (code) {
    'SESSION_EXPIRED' ||
    'UNAUTHENTICATED' => 'Session expired. Refresh to continue.',
    'RATE_LIMITED' => 'Too many attempts. Try again shortly.',
    'NOT_FOUND' => 'This item is no longer available.',
    'STATION_UNAVAILABLE' => 'Station unavailable. Try again later.',
    'MISSING_DOCUMENT' => 'Select a document.',
    'UNSUPPORTED_TYPE' => 'Choose a PDF, PNG or JPG file.',
    'INVALID_FILENAME' => 'Rename the file and try again.',
    'INVALID_FILE' ||
    'DOCUMENT_TIMEOUT' => 'Unable to process this file. Choose another.',
    'FILE_TOO_LARGE' => 'File exceeds the upload limit. Choose a smaller file.',
    'STORAGE_QUOTA' => 'Upload limit reached. Contact the station.',
    'DOCUMENT_EXPIRED' => 'Document expired. Upload it again.',
    'DOCUMENT_INTEGRITY' => 'Document unavailable. Contact the station.',
    'DOCUMENT_IN_USE' => 'This document belongs to an existing order.',
    'INVALID_PAGE_RANGE' => 'Check the page range against this document.',
    'INVALID_QUANTITY' => 'Choose 1–100 copies.',
    'ORDER_TOO_LARGE' => 'Too many pages. Reduce the selection or copies.',
    'INCONSISTENT_LAYOUT' =>
      'Use the same paper size, orientation and sides for all files.',
    'UNSUPPORTED_OPTIONS' => 'These options are unavailable at this station.',
    'VALIDATION_ERROR' => 'Check your entries and try again.',
    'INVALID_OTP' ||
    'RELEASE_FAILED' => 'Code invalid, expired or already used.',
    'OTP_EXPIRED' => 'Code expired. Refund pending.',
    'OTP_NOT_AVAILABLE' ||
    'OTP_ALREADY_ISSUED' => 'Release code unavailable. Check your order.',
    'OTP_UNAVAILABLE' => 'Unable to load the release code. Try again.',
    'PAYMENTS_UNAVAILABLE' => 'Payments unavailable. Try again later.',
    'GATEWAY_UNAVAILABLE' ||
    'PAYMENT_RECONCILING' ||
    'PAYMENT_NOT_CAPTURED' ||
    'PAYMENT_REQUIRED' =>
      'Payment unconfirmed. Check status before paying again.',
    'PAYMENT_REFUNDED' => 'Payment refunded.',
    'PAYMENT_CONFIGURATION_CHANGED' ||
    'PAYMENT_CONFLICT' ||
    'RECONCILIATION_REVIEW' =>
      'Payment needs review. Contact the station before paying again.',
    'PAYMENT_MISMATCH' ||
    'PAYMENT_REUSED' ||
    'INVALID_SIGNATURE' ||
    'INVALID_GATEWAY_ID' =>
      'Payment could not be verified. Check payment status.',
    'PAYMENT_NOT_CREATED' => 'Payment not started. Retry checkout.',
    'IDEMPOTENCY_CONFLICT' => 'Order options changed. Review your order.',
    'INVALID_STATE' ||
    'JOB_ALREADY_CLAIMED' => 'Order updated. Check its status.',
    _ => 'Unable to complete the request. Try again.',
  });

  @override
  String toString() => message;
}

String userError(
  Object error, {
  String fallback = 'Unable to connect. Try again.',
}) => error is ApiError ? error.message : fallback;
