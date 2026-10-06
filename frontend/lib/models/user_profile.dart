class UserProfile {
  final int id;
  final String? email;
  final String? fullName;
  final String? rollNumber;
  final String? department;
  final String role;
  final bool isActive;
  final DateTime? createdAt;

  UserProfile({
    required this.id,
    this.email,
    this.fullName,
    this.rollNumber,
    this.department,
    required this.role,
    this.isActive = true,
    this.createdAt,
  });

  String get displayName => (fullName?.trim().isNotEmpty == true)
      ? fullName!.trim()
      : (rollNumber?.trim().isNotEmpty == true)
      ? rollNumber!.trim()
      : (email?.trim().isNotEmpty == true)
      ? email!.split('@').first
      : 'User';

  String get initials {
    final name = displayName;
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty
        ? name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase()
        : 'U';
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      email: json['email'] as String?,
      fullName: (json['full_name'] ?? json['fullName']) as String?,
      rollNumber: (json['roll_number'] ?? json['rollNumber']) as String?,
      department: json['department'] as String?,
      role: json['role'] as String? ?? 'USER',
      isActive: json['is_active'] == true || json['isActive'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'full_name': fullName,
    'roll_number': rollNumber,
    'department': department,
    'role': role,
    'is_active': isActive,
    'created_at': createdAt?.toIso8601String(),
  };
}
