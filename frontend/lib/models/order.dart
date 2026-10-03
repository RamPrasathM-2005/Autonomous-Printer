class PrintLineItem {
  final String filename;
  final int pages;
  final int copies;
  final bool colour;
  final String amount;
  const PrintLineItem({
    required this.filename,
    required this.pages,
    required this.copies,
    required this.colour,
    required this.amount,
  });
  factory PrintLineItem.fromJson(Map<String, dynamic> json) => PrintLineItem(
    filename: json['filename'] as String? ?? 'Document',
    pages: (json['pages'] as num?)?.toInt() ?? 0,
    copies: (json['copies'] as num?)?.toInt() ?? 1,
    colour: json['colour'] == true,
    amount: num.tryParse('${json['amount']}')?.toStringAsFixed(2) ?? '',
  );
}

class PrintSettings {
  final String pageRange;
  final int copies;
  final bool colour;
  final String sides; // one-sided, two-sided-long-edge, two-sided-short-edge
  final String paperSize; // A4, Letter, Legal
  final String orientation; // portrait, landscape
  final bool mockPrinting;
  final List<PrintLineItem> items;

  PrintSettings({
    this.pageRange = 'all',
    this.copies = 1,
    this.colour = false,
    this.sides = 'one-sided',
    this.paperSize = 'A4',
    this.orientation = 'portrait',
    this.mockPrinting = false,
    this.items = const [],
  });

  Map<String, dynamic> toJson() => {
    'pageRange': pageRange,
    'copies': copies,
    'colour': colour,
    'sides': sides,
    'paperSize': paperSize,
    'orientation': orientation,
  };

  factory PrintSettings.fromJson(Map<String, dynamic> json) {
    return PrintSettings(
      pageRange: json['pageRange'] ?? json['page_range'] ?? 'all',
      copies: json['copies'] ?? 1,
      colour: json['colour'] ?? false,
      sides: json['sides'] ?? 'one-sided',
      paperSize: json['paperSize'] ?? json['paper_size'] ?? 'A4',
      orientation: json['orientation'] ?? 'portrait',
      mockPrinting: json['mockPrinting'] == true,
      items: (json['items'] as List? ?? const [])
          .map(
            (item) =>
                PrintLineItem.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
    );
  }
}

class PrintOrder {
  final String id;
  final String? userId;
  final String? rollNumber;
  final String? department;
  final String documentId;
  final String printServerId;
  final PrintSettings printSettings;
  final int totalPages;
  final int copies;
  final double amount;
  final String currency;
  final String status;
  final String createdAt;

  PrintOrder({
    required this.id,
    this.userId,
    this.rollNumber,
    this.department,
    required this.documentId,
    required this.printServerId,
    required this.printSettings,
    required this.totalPages,
    required this.copies,
    required this.amount,
    required this.currency,
    required this.status,
    required this.createdAt,
  });

  String get formattedAmount => '₹${amount.toStringAsFixed(2)}';

  bool get isWaitingOtp => status.toUpperCase() == 'WAITING_FOR_OTP';
  String get statusLabel => switch (status.toUpperCase()) {
    'CREATED' || 'WAITING_FOR_PAYMENT' => 'Awaiting payment',
    'PAID' => 'Paid',
    'JOB_QUEUED' => 'Queued',
    'WAITING_FOR_OTP' => 'Ready to release',
    'RELEASED' => 'Queued for printing',
    'PRINTING' => 'Printing',
    'COMPLETED' => 'Completed',
    'FAILED' => 'Needs attention',
    'EXPIRED' => 'Expired',
    'REFUNDED' => 'Refunded',
    'CANCELLED' => 'Cancelled',
    _ => 'Status unavailable',
  };
  bool get isCompleted => status.toUpperCase() == 'COMPLETED';
  bool get isPrinting => status.toUpperCase() == 'PRINTING';
  bool get isPendingPayment => status.toUpperCase() == 'WAITING_FOR_PAYMENT';

  bool get isColor => printSettings.colour;
  bool get duplex => printSettings.sides != 'one-sided';
  String get paperSize => printSettings.paperSize;
  String get pageRange => printSettings.pageRange;

  factory PrintOrder.fromJson(Map<String, dynamic> json) {
    return PrintOrder(
      id: json['id'] ?? '',
      userId: (json['userId'] ?? json['user_id'])?.toString(),
      rollNumber: json['rollNumber'] ?? json['roll_number'],
      department: json['department'],
      documentId: json['documentId'] ?? json['document_id'] ?? '',
      printServerId: json['printServerId'] ?? json['print_server_id'] ?? '',
      printSettings: (json['printSettings'] ?? json['print_settings']) != null
          ? PrintSettings.fromJson(
              (json['printSettings'] ?? json['print_settings'])
                  as Map<String, dynamic>,
            )
          : PrintSettings(),
      totalPages: json['totalPages'] ?? json['total_pages'] ?? 1,
      copies: json['copies'] ?? 1,
      amount: (json['amount'] is num)
          ? (json['amount'] as num).toDouble()
          : 0.0,
      currency: json['currency'] ?? 'INR',
      status: json['status'] ?? 'WAITING_FOR_PAYMENT',
      createdAt: json['createdAt'] ?? json['created_at'] ?? '',
    );
  }
}

class OrderOtp {
  final String orderId;
  final String otp;
  final String expiresAt;
  final Map<String, dynamic>? printerOtps;
  final String? selectedPrinter;
  final bool printerSelectionLocked;

  OrderOtp({
    required this.orderId,
    required this.otp,
    required this.expiresAt,
    this.printerOtps,
    this.selectedPrinter,
    this.printerSelectionLocked = false,
  });

  String get otpCode {
    if (selectedPrinter != null && printerOtps != null) {
      final pInfo = printerOtps![selectedPrinter];
      if (pInfo is Map && pInfo['otp'] != null) {
        return pInfo['otp'].toString();
      }
      final isUnit2 = selectedPrinter!.contains('E9A0F4') ||
          selectedPrinter!.contains('Unit 2') ||
          selectedPrinter!.contains('Printer_2');
      if (isUnit2) {
        final p2 = printerOtps!['HP_LaserJet_400_M401dn_E9A0F4'] ??
            printerOtps!['Printer_2'];
        if (p2 is Map && p2['otp'] != null) {
          return p2['otp'].toString();
        }
      } else {
        final p1 = printerOtps!['HP_LaserJet_400_M401dn_F36EC0'];
        if (p1 is Map && p1['otp'] != null) {
          return p1['otp'].toString();
        }
      }
    }
    return otp;
  }

  factory OrderOtp.fromJson(Map<String, dynamic> json) {
    return OrderOtp(
      orderId: json['orderId'] ?? json['order_id'] ?? '',
      otp: json['otp'] ?? '',
      expiresAt: json['expiresAt'] ?? json['expires_at'] ?? '',
      printerOtps: json['printerOtps'] ?? json['printer_otps'],
      selectedPrinter: json['selectedPrinter'] ?? json['selected_printer'],
      printerSelectionLocked:
          json['printerSelectionLocked'] == true ||
          json['printer_selection_locked'] == true,
    );
  }
}
