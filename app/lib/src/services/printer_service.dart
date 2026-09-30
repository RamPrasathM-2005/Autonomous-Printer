import '../constants/api_constants.dart';
import '../models/printer_status_model.dart';
import '../models/print_job_model.dart';
import 'api_client.dart';

class PrinterService {
  final ApiClient _client = ApiClient();

  Future<PrinterStatusModel> getPrinterStatus() async {
    try {
      final response = await _client.get(ApiConstants.printerStatus);
      if (response is Map<String, dynamic>) {
        return PrinterStatusModel.fromJson(response);
      }
    } catch (_) {}

    return PrinterStatusModel.fallbackReady();
  }

  Future<PrintJobModel> getJobStatus(String jobId, {String? orderId, int step = 0}) async {
    try {
      final response = await _client.get(ApiConstants.printerJobStatus(jobId));
      if (response is Map<String, dynamic>) {
        return PrintJobModel.fromJson(response, defaultOrderId: orderId);
      }
    } catch (_) {}

    // Simulated state machine progression for demonstration
    PrintJobStatus status = PrintJobStatus.queued;
    double progress = 0.15;
    int printedPages = 1;
    int totalPages = 5;

    if (step >= 4) {
      status = PrintJobStatus.completed;
      progress = 1.0;
      printedPages = totalPages;
    } else if (step >= 2) {
      status = PrintJobStatus.printing;
      progress = 0.65;
      printedPages = 3;
    } else if (step >= 1) {
      status = PrintJobStatus.processing;
      progress = 0.35;
      printedPages = 0;
    }

    return PrintJobModel(
      jobId: jobId,
      orderId: orderId ?? 'ORD-001',
      status: status,
      queuePosition: step == 0 ? 1 : 0,
      printerName: 'Kiosk HP LaserJet M507',
      printedPages: printedPages,
      totalPages: totalPages,
      progress: progress,
      updatedAt: DateTime.now(),
    );
  }
}
