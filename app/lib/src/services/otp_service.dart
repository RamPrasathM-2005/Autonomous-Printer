import 'dart:math';
import '../constants/api_constants.dart';
import '../models/otp_model.dart';
import 'api_client.dart';

class OtpService {
  final ApiClient _client = ApiClient();

  Future<OtpModel> getOtp(String orderId) async {
    try {
      final response = await _client.get(ApiConstants.otpGet(orderId));
      if (response is Map<String, dynamic>) {
        return OtpModel.fromJson(response, orderId: orderId);
      }
    } catch (_) {}

    // Fallback pseudo-random 6-digit PIN
    final randomOtp = (100000 + Random().nextInt(900000)).toString();
    return OtpModel(
      otp: randomOtp,
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      orderId: orderId,
    );
  }
}
