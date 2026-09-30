import 'print_configuration_model.dart';

enum OrderStatus { created, paid, failed, cancelled, completed }

class OrderItemModel {
  final String documentId;
  final String fileName;
  final int pageCount;
  final PrintConfigurationModel configuration;
  final double itemTotal;

  const OrderItemModel({
    required this.documentId,
    required this.fileName,
    required this.pageCount,
    required this.configuration,
    required this.itemTotal,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      documentId: json['documentId'] ?? '',
      fileName: json['fileName'] ?? 'Document',
      pageCount: json['pageCount'] ?? 1,
      configuration: PrintConfigurationModel.fromJson(json['configuration'] ?? {}),
      itemTotal: (json['itemTotal'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'documentId': documentId,
      'fileName': fileName,
      'pageCount': pageCount,
      'configuration': configuration.toJson(),
      'itemTotal': itemTotal,
    };
  }
}

class OrderModel {
  final String orderId;
  final List<OrderItemModel> items;
  final double subtotal;
  final double serviceFee;
  final double tax;
  final double total;
  final String currency;
  final OrderStatus status;
  final DateTime createdAt;

  const OrderModel({
    required this.orderId,
    required this.items,
    required this.subtotal,
    required this.serviceFee,
    required this.tax,
    required this.total,
    this.currency = 'INR',
    this.status = OrderStatus.created,
    required this.createdAt,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    var rawItems = json['items'] as List? ?? [];
    List<OrderItemModel> parsedItems = rawItems
        .map((item) => OrderItemModel.fromJson(item as Map<String, dynamic>))
        .toList();

    return OrderModel(
      orderId: json['orderId'] ?? '',
      items: parsedItems,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      serviceFee: (json['serviceFee'] as num?)?.toDouble() ?? 0.0,
      tax: (json['tax'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'INR',
      status: _parseStatus(json['status']),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
      'items': items.map((i) => i.toJson()).toList(),
      'subtotal': subtotal,
      'serviceFee': serviceFee,
      'tax': tax,
      'total': total,
      'currency': currency,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static OrderStatus _parseStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'paid':
        return OrderStatus.paid;
      case 'failed':
        return OrderStatus.failed;
      case 'cancelled':
        return OrderStatus.cancelled;
      case 'completed':
        return OrderStatus.completed;
      default:
        return OrderStatus.created;
    }
  }
}
