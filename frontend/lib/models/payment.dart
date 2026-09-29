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
    final rawKey = json['keyId'] ?? json['key_id'] ?? '';
    final keyId = (rawKey is String && rawKey.isNotEmpty)
        ? rawKey
        : 'rzp_test_RFxhjAiTxwrpAJ';

    final rawOrderId = json['razorpayOrderId'] ?? json['razorpay_order_id'] ?? '';
    final rzpOrderId = (rawOrderId is String && rawOrderId.isNotEmpty)
        ? rawOrderId
        : '';

    return PaymentInitiateResponse(
      orderId: json['orderId'] ?? json['order_id'] ?? '',
      razorpayOrderId: rzpOrderId,
      amount: (json['amount'] is num) ? (json['amount'] as num).toDouble() : 0.0,
      currency: json['currency'] ?? 'INR',
      keyId: keyId,
    );
  }
}

typedef PaymentOrderResponse = PaymentInitiateResponse;
