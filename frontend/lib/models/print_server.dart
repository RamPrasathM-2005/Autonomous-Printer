class Printer {
  final String id;
  final String serverId;
  final String cupsQueueName;
  final String displayName;
  final String? model;
  final String? location;
  final int? departmentId;
  final String driver;
  final bool isDefault;
  final bool isActive;
  final bool isEnabled;
  final bool supportsColor;
  final bool supportsDuplex;
  final List<String> supportedMedia;
  final String state;

  Printer({
    required this.id,
    required this.serverId,
    required this.cupsQueueName,
    required this.displayName,
    this.model,
    this.location,
    this.departmentId,
    required this.driver,
    required this.isDefault,
    required this.isActive,
    required this.isEnabled,
    required this.supportsColor,
    required this.supportsDuplex,
    required this.supportedMedia,
    required this.state,
  });

  factory Printer.fromJson(Map<String, dynamic> json) {
    final cupsName = json['cups_printer_name'] ?? json['cups_queue_name'] ?? '';
    final name = json['display_name'] ?? (cupsName.isNotEmpty ? cupsName : 'Station Printer');
    return Printer(
      id: json['id']?.toString() ?? '',
      serverId: json['server_id']?.toString() ?? '',
      cupsQueueName: cupsName,
      displayName: name,
      model: json['model']?.toString(),
      location: json['location']?.toString(),
      departmentId: json['department_id'] is int ? json['department_id'] : int.tryParse(json['department_id']?.toString() ?? ''),
      driver: json['driver'] ?? '',
      isDefault: json['is_default'] ?? false,
      isActive: json['is_active'] ?? true,
      isEnabled: json['is_enabled'] ?? true,
      supportsColor: json['supports_color'] ?? false,
      supportsDuplex: json['supports_duplex'] ?? false,
      supportedMedia:
          (json['supported_media'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['A4'],
      state: json['printer_status'] ?? json['state'] ?? 'READY',
    );
  }
}

class PrintServer {
  final String id;
  final String name;
  final String location;
  final int? departmentId;
  final String status; // ONLINE, OFFLINE, MAINTENANCE, DISABLED
  final String? lastHeartbeat;
  final String printerState; // IDLE, PRINTING, ERROR, UNKNOWN
  final String paperState; // NORMAL, LOW, EMPTY, UNKNOWN
  final List<Printer> printers;

  PrintServer({
    required this.id,
    required this.name,
    required this.location,
    this.departmentId,
    required this.status,
    this.lastHeartbeat,
    required this.printerState,
    required this.paperState,
    required this.printers,
  });

  bool get isOnline => status.toUpperCase() == 'ONLINE';
  bool get canAcceptJobs => isOnline && paperState.toUpperCase() != 'EMPTY';

  factory PrintServer.fromJson(Map<String, dynamic> json) {
    var rawPrinters = json['printers'] as List<dynamic>?;
    List<Printer> parsedPrinters = [];
    if (rawPrinters != null) {
      parsedPrinters = rawPrinters
          .map((p) => Printer.fromJson(p as Map<String, dynamic>))
          .toList();
    }

    return PrintServer(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Print Station',
      location: json['location'] ?? 'Unknown Location',
      departmentId: json['department_id'] is int ? json['department_id'] : int.tryParse(json['department_id']?.toString() ?? ''),
      status: json['status'] ?? 'OFFLINE',
      lastHeartbeat: json['last_heartbeat'],
      printerState: json['printer_state'] ?? 'UNKNOWN',
      paperState: json['paper_state'] ?? 'UNKNOWN',
      printers: parsedPrinters,
    );
  }
}
