enum PaymentStatus { idle, initiating, processing, successful, failed }
enum PaymentMethod { upi, card, netbanking, mock }

class PaymentOrderResponse {
  final String razorpayOrderId;
  final String keyId;
  final int amountInPaise;
  final String currency;
  final String orderId;

  const PaymentOrderResponse({
    required this.razorpayOrderId,
    required this.keyId,
    required this.amountInPaise,
    required this.currency,
    required this.orderId,
  });

  factory PaymentOrderResponse.fromJson(Map<String, dynamic> json) {
    return PaymentOrderResponse(
      razorpayOrderId: json['razorpayOrderId'] ?? json['id'] ?? '',
      keyId: json['keyId'] ?? 'rzp_test_mockKey',
      amountInPaise: (json['amount'] as num?)?.toInt() ?? 0,
      currency: json['currency'] ?? 'INR',
      orderId: json['orderId'] ?? '',
    );
  }
}

class PaymentResultModel {
  final bool success;
  final String? paymentId;
  final String? orderId;
  final String? signature;
  final String? errorCode;
  final String? errorMessage;

  const PaymentResultModel({
    required this.success,
    this.paymentId,
    this.orderId,
    this.signature,
    this.errorCode,
    this.errorMessage,
  });
}
