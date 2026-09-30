class PrinterStatusModel {
  final bool isOnline;
  final String printerName;
  final String paperStatus; // 'ok', 'low', 'empty'
  final int queueLength;
  final bool isReady;
  final String? alertMessage;

  const PrinterStatusModel({
    required this.isOnline,
    required this.printerName,
    required this.paperStatus,
    required this.queueLength,
    required this.isReady,
    this.alertMessage,
  });

  factory PrinterStatusModel.fromJson(Map<String, dynamic> json) {
    final status = json['status']?.toString().toLowerCase() ?? 'offline';
    final paper = json['paperStatus']?.toString().toLowerCase() ?? 'ok';
    final isOnline = status == 'online' || status == 'ready' || status == 'idle';
    final isReady = isOnline && paper != 'empty';

    return PrinterStatusModel(
      isOnline: isOnline,
      printerName: json['printerName'] ?? 'Station Kiosk #1',
      paperStatus: paper,
      queueLength: (json['queueLength'] as num?)?.toInt() ?? 0,
      isReady: isReady,
      alertMessage: json['message'] ?? json['alertMessage'],
    );
  }

  factory PrinterStatusModel.fallbackReady() {
    return const PrinterStatusModel(
      isOnline: true,
      printerName: 'Autonomous Kiosk Printer #101',
      paperStatus: 'ok',
      queueLength: 0,
      isReady: true,
    );
  }
}
