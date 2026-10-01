class Printer {
  final String id;
  final String serverId;
  final String cupsQueueName;
  final String displayName;
  final String driver;
  final bool isDefault;
  final bool isActive;
  final bool supportsColor;
  final bool supportsDuplex;
  final List<String> supportedMedia;
  final String state;

  Printer({
    required this.id,
    required this.serverId,
    required this.cupsQueueName,
    required this.displayName,
    required this.driver,
    required this.isDefault,
    required this.isActive,
    required this.supportsColor,
    required this.supportsDuplex,
    required this.supportedMedia,
    required this.state,
  });

  factory Printer.fromJson(Map<String, dynamic> json) {
    return Printer(
      id: json['id'] ?? '',
      serverId: json['server_id'] ?? '',
      cupsQueueName: json['cups_queue_name'] ?? '',
      displayName: json['display_name'] ?? 'Station Printer',
      driver: json['driver'] ?? '',
      isDefault: json['is_default'] ?? false,
      isActive: json['is_active'] ?? true,
      supportsColor: json['supports_color'] ?? false,
      supportsDuplex: json['supports_duplex'] ?? false,
      supportedMedia:
          (json['supported_media'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['A4'],
      state: json['state'] ?? 'idle',
    );
  }
}

class PrintServer {
  final String id;
  final String name;
  final String location;
  final String status; // ONLINE, OFFLINE, MAINTENANCE, DISABLED
  final String? lastHeartbeat;
  final String printerState; // IDLE, PRINTING, ERROR, UNKNOWN
  final String paperState; // NORMAL, LOW, EMPTY, UNKNOWN
  final List<Printer> printers;

  PrintServer({
    required this.id,
    required this.name,
    required this.location,
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
      status: json['status'] ?? 'OFFLINE',
      lastHeartbeat: json['last_heartbeat'],
      printerState: json['printer_state'] ?? 'UNKNOWN',
      paperState: json['paper_state'] ?? 'UNKNOWN',
      printers: parsedPrinters,
    );
  }
}
