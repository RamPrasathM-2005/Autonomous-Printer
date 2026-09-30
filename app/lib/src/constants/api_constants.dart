class ApiConstants {
  static const String baseUrl = 'http://10.0.2.2:8000'; // 10.0.2.2 maps to host localhost on Android Emulator
  static const String fallbackLocalUrl = 'http://192.168.1.100:8000';
  static const String appVersion = '1.0.0';
  static const Duration timeout = Duration(seconds: 15);

  // Endpoints
  static const String health = '/api/health';
  static const String printerStatus = '/api/printer/status';
  static String printerJobStatus(String jobId) => '/api/printer/job-status/$jobId';
  static const String documentsUpload = '/api/documents/upload';
  static String documentsDelete(String id) => '/api/documents/$id';
  static const String ordersCreate = '/api/orders/create';
  static String ordersStatus(String id) => '/api/orders/$id/status';
  static String ordersCancel(String id) => '/api/orders/$id';
  static const String paymentsCreate = '/api/payments/create';
  static String otpGet(String orderId) => '/api/otp/$orderId';

  // Base Pricing Defaults (in INR)
  static const double bwSinglePrice = 2.00;
  static const double bwDuplexPrice = 3.50;
  static const double colorSinglePrice = 10.00;
  static const double colorDuplexPrice = 18.00;
  static const double serviceFee = 1.00;
  static const double gstRate = 0.18;
}
