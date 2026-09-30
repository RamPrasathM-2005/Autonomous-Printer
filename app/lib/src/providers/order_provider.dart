import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../models/document_model.dart';
import '../models/print_configuration_model.dart';
import '../services/order_service.dart';

class OrderProvider with ChangeNotifier {
  final OrderService _service = OrderService();
  OrderModel? _currentOrder;
  bool _isLoading = false;
  String? _errorMessage;

  OrderModel? get currentOrder => _currentOrder;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<OrderModel?> createOrder({
    required List<DocumentModel> documents,
    required Map<String, PrintConfigurationModel> configurations,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final order = await _service.createOrder(
        documents: documents,
        configurations: configurations,
      );
      _currentOrder = order;
      return order;
    } catch (e) {
      _errorMessage = 'Failed to create order: $e';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setCurrentOrder(OrderModel order) {
    _currentOrder = order;
    notifyListeners();
  }

  void reset() {
    _currentOrder = null;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
}
