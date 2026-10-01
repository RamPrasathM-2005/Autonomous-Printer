class RazorpayWebPaymentResult {
  final bool success;
  final String razorpayPaymentId;
  final String razorpayOrderId;
  final String razorpaySignature;
  final String? errorMessage;
  const RazorpayWebPaymentResult({
    required this.success,
    this.razorpayPaymentId = '',
    this.razorpayOrderId = '',
    this.razorpaySignature = '',
    this.errorMessage,
  });
}
