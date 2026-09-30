import 'dart:async';
import 'package:flutter/material.dart';
import '../models/otp_model.dart';
import '../services/otp_service.dart';

class OtpProvider with ChangeNotifier {
  final OtpService _service = OtpService();
  OtpModel? _otpModel;
  Timer? _countdownTimer;
  Duration _remainingTime = const Duration(minutes: 10);
  bool _isLoading = false;

  OtpModel? get otpModel => _otpModel;
  Duration get remainingTime => _remainingTime;
  bool get isLoading => _isLoading;
  bool get isExpired => _remainingTime == Duration.zero;

  Future<void> fetchOtp(String orderId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final otp = await _service.getOtp(orderId);
      _otpModel = otp;
      _remainingTime = otp.remainingTime;
      _startTimer();
    } catch (_) {
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime.inSeconds > 0) {
        _remainingTime = _remainingTime - const Duration(seconds: 1);
        notifyListeners();
      } else {
        _countdownTimer?.cancel();
        notifyListeners();
      }
    });
  }

  void reset() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _otpModel = null;
    _remainingTime = const Duration(minutes: 10);
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }
}
