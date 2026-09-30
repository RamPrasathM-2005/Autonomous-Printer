import 'package:flutter/material.dart';
import '../models/payment_model.dart';
import '../services/payment_service.dart';

class PaymentProvider with ChangeNotifier {
  final PaymentService _service = PaymentService();
  PaymentStatus _status = PaymentStatus.idle;
  PaymentResultModel? _lastResult;
  String? _errorMessage;

  PaymentStatus get status => _status;
  PaymentResultModel? get lastResult => _lastResult;
  String? get errorMessage => _errorMessage;

  Future<bool> processPayment({
    required String orderId,
    required double amountInRupees,
    required PaymentMethod method,
  }) async {
    _status = PaymentStatus.initiating;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Create order token
      await _service.createPaymentOrder(orderId, amountInRupees);

      _status = PaymentStatus.processing;
      notifyListeners();

      // 2. Perform payment transaction
      final result = await _service.processMockPayment(orderId, method);
      _lastResult = result;

      if (result.success) {
        _status = PaymentStatus.successful;
        notifyListeners();
        return true;
      } else {
        _status = PaymentStatus.failed;
        _errorMessage = result.errorMessage ?? 'Payment transaction was declined.';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _status = PaymentStatus.failed;
      _errorMessage = 'Payment error: $e';
      notifyListeners();
      return false;
    }
  }

  void reset() {
    _status = PaymentStatus.idle;
    _lastResult = null;
    _errorMessage = null;
    notifyListeners();
  }
}
