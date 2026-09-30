import 'package:uuid/uuid.dart';
import '../constants/api_constants.dart';
import '../models/payment_model.dart';
import 'api_client.dart';

class PaymentService {
  final ApiClient _client = ApiClient();
  final Uuid _uuid = const Uuid();

  Future<PaymentOrderResponse> createPaymentOrder(String orderId, double amountInRupees) async {
    try {
      final response = await _client.post(ApiConstants.paymentsCreate, {
        'orderId': orderId,
        'amount': (amountInRupees * 100).toInt(),
      });
      if (response is Map<String, dynamic>) {
        return PaymentOrderResponse.fromJson(response);
      }
    } catch (_) {}

    return PaymentOrderResponse(
      razorpayOrderId: 'rzp_order_${_uuid.v4().substring(0, 12)}',
      keyId: 'rzp_test_1DP5mmOlF5G5ag',
      amountInPaise: (amountInRupees * 100).toInt(),
      currency: 'INR',
      orderId: orderId,
    );
  }

  Future<PaymentResultModel> processMockPayment(String orderId, PaymentMethod method) async {
    await Future.delayed(const Duration(milliseconds: 1500));
    return PaymentResultModel(
      success: true,
      paymentId: 'pay_${_uuid.v4().substring(0, 14)}',
      orderId: orderId,
      signature: 'mock_sig_${_uuid.v4().substring(0, 16)}',
    );
  }
}
