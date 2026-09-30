import 'dart:async';
import 'package:flutter/material.dart';
import '../models/print_job_model.dart';
import '../services/printer_service.dart';

class PrintStatusProvider with ChangeNotifier {
  final PrinterService _service = PrinterService();
  PrintJobModel? _currentJob;
  Timer? _pollingTimer;
  int _stepCounter = 0;
  bool _isCancelled = false;

  PrintJobModel? get currentJob => _currentJob;
  bool get isCompleted => _currentJob?.status == PrintJobStatus.completed;
  bool get isFailed => _currentJob?.status == PrintJobStatus.failed;
  bool get isPrinting => _currentJob?.status == PrintJobStatus.printing;

  void startTracking(String jobId, String orderId) {
    _stepCounter = 0;
    _isCancelled = false;
    _pollingTimer?.cancel();

    // Initial fetch
    _fetchStatus(jobId, orderId);

    // Poll every 2 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_isCancelled || _currentJob?.status == PrintJobStatus.completed) {
        timer.cancel();
        return;
      }
      _stepCounter++;
      _fetchStatus(jobId, orderId);
    });
  }

  Future<void> _fetchStatus(String jobId, String orderId) async {
    final status = await _service.getJobStatus(jobId, orderId: orderId, step: _stepCounter);
    _currentJob = status;
    notifyListeners();
  }

  void cancelJob() {
    _isCancelled = true;
    _pollingTimer?.cancel();
    if (_currentJob != null) {
      _currentJob = PrintJobModel(
        jobId: _currentJob!.jobId,
        orderId: _currentJob!.orderId,
        status: PrintJobStatus.cancelled,
        printerName: _currentJob!.printerName,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
    }
  }

  void reset() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _currentJob = null;
    _stepCounter = 0;
    _isCancelled = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
