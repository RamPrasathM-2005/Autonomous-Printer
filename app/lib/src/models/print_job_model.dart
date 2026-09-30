enum PrintJobStatus {
  idle,
  pending,
  queued,
  processing,
  printing,
  completed,
  failed,
  cancelled
}

class PrintJobModel {
  final String jobId;
  final String orderId;
  final PrintJobStatus status;
  final int queuePosition;
  final String printerName;
  final int printedPages;
  final int totalPages;
  final double progress; // 0.0 to 1.0
  final String? errorMessage;
  final DateTime updatedAt;

  const PrintJobModel({
    required this.jobId,
    required this.orderId,
    required this.status,
    this.queuePosition = 0,
    this.printerName = 'Autonomous Kiosk Printer',
    this.printedPages = 0,
    this.totalPages = 1,
    this.progress = 0.0,
    this.errorMessage,
    required this.updatedAt,
  });

  factory PrintJobModel.fromJson(Map<String, dynamic> json, {String? defaultOrderId}) {
    return PrintJobModel(
      jobId: json['jobId']?.toString() ?? '',
      orderId: json['orderId']?.toString() ?? defaultOrderId ?? '',
      status: _parseJobStatus(json['jobStatus'] ?? json['status']),
      queuePosition: (json['queuePosition'] as num?)?.toInt() ?? 0,
      printerName: json['printerName'] ?? 'Autonomous Kiosk Printer',
      printedPages: (json['printedPages'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      errorMessage: json['errorMessage'],
      updatedAt: DateTime.now(),
    );
  }

  static PrintJobStatus _parseJobStatus(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'queued':
        return PrintJobStatus.queued;
      case 'processing':
        return PrintJobStatus.processing;
      case 'printing':
        return PrintJobStatus.printing;
      case 'completed':
      case 'done':
        return PrintJobStatus.completed;
      case 'failed':
      case 'error':
        return PrintJobStatus.failed;
      case 'cancelled':
        return PrintJobStatus.cancelled;
      default:
        return PrintJobStatus.pending;
    }
  }

  String get readableStatus {
    switch (status) {
      case PrintJobStatus.queued:
        return 'In Queue (Position #$queuePosition)';
      case PrintJobStatus.processing:
        return 'Preparing Document...';
      case PrintJobStatus.printing:
        return 'Printing Page $printedPages of $totalPages';
      case PrintJobStatus.completed:
        return 'Print Complete! Please Collect Papers';
      case PrintJobStatus.failed:
        return 'Print Failed: ${errorMessage ?? "Hardware Issue"}';
      case PrintJobStatus.cancelled:
        return 'Job Cancelled';
      default:
        return 'Pending Verification';
    }
  }
}
