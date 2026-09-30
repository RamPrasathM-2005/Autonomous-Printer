class OtpModel {
  final String otp;
  final DateTime expiresAt;
  final String orderId;

  const OtpModel({
    required this.otp,
    required this.expiresAt,
    required this.orderId,
  });

  factory OtpModel.fromJson(Map<String, dynamic> json, {String? orderId}) {
    DateTime exp;
    if (json['expiresAt'] != null) {
      exp = DateTime.tryParse(json['expiresAt']) ??
          DateTime.now().add(const Duration(minutes: 10));
    } else {
      exp = DateTime.now().add(const Duration(minutes: 10));
    }

    return OtpModel(
      otp: json['otp']?.toString() ?? '------',
      expiresAt: exp,
      orderId: orderId ?? json['orderId'] ?? '',
    );
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Duration get remainingTime {
    final diff = expiresAt.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }
}
