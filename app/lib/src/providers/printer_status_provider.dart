import 'package:flutter/material.dart';
import '../models/printer_status_model.dart';
import '../services/printer_service.dart';

class PrinterStatusProvider with ChangeNotifier {
  final PrinterService _service = PrinterService();
  PrinterStatusModel _status = PrinterStatusModel.fallbackReady();
  bool _isLoading = false;

  PrinterStatusModel get status => _status;
  bool get isLoading => _isLoading;

  Future<void> refreshStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await _service.getPrinterStatus();
      _status = res;
    } catch (_) {
      _status = PrinterStatusModel.fallbackReady();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
