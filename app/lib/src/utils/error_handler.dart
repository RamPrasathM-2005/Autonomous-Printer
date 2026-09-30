class AppError {
  final String code;
  final String message;
  final int? statusCode;

  const AppError({
    required this.code,
    required this.message,
    this.statusCode,
  });

  factory AppError.fromException(dynamic error) {
    if (error is AppError) return error;

    final str = error.toString().toLowerCase();
    if (str.contains('socketexception') || str.contains('connection refused') || str.contains('network_unavailable')) {
      return const AppError(
        code: 'NETWORK_ERROR',
        message: 'Unable to connect to printer server. Please verify Wi-Fi / kiosk connection.',
      );
    }
    if (str.contains('timeout')) {
      return const AppError(
        code: 'TIMEOUT',
        message: 'The request took too long. Please try again.',
      );
    }
    return AppError(
      code: 'UNKNOWN_ERROR',
      message: error.toString(),
    );
  }

  @override
  String toString() => message;
}
