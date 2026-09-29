class PaymentInitiateResponse {
  final String orderId;
  final String razorpayOrderId;
  final double amount;
  final String currency;
  final String keyId;

  PaymentInitiateResponse({
    required this.orderId,
    required this.razorpayOrderId,
    required this.amount,
    required this.currency,
    required this.keyId,
  });

  factory PaymentInitiateResponse.fromJson(Map<String, dynamic> json) {
    return PaymentInitiateResponse(
      orderId: json['order_id'] ?? '',
      razorpayOrderId: json['razorpay_order_id'] ?? '',
      amount: (json['amount'] is num) ? (json['amount'] as num).toDouble() : 0.0,
      currency: json['currency'] ?? 'INR',
      keyId: json['key_id'] ?? '',
    );
  }
}
