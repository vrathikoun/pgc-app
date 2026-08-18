class Member {
  final int id;
  final String email;
  final String firstName;
  final String lastName;
  final String? phone;
  final String? emergencyContact;
  final String? avatarUrl;
  final String? beltRank;
  final String role;
  final bool isActive;
  final String subscriptionPlan;
  final int? weeklyBookingLimit;
  final DateTime? createdAt;

  Member({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.emergencyContact,
    this.avatarUrl,
    this.beltRank,
    required this.role,
    required this.isActive,
    required this.subscriptionPlan,
    this.weeklyBookingLimit,
    this.createdAt,
  });

  String get fullName => '$firstName $lastName'.trim();

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = lastName.isNotEmpty ? lastName[0] : '';
    final value = '$f$l'.trim();
    return value.isEmpty ? 'PGC' : value;
  }

  bool get isAdmin => role == 'admin';
  bool get isCoach => role == 'coach';

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'],
      email: json['email'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      phone: json['phone'],
      emergencyContact: json['emergency_contact'],
      avatarUrl: json['avatar_url'],
      beltRank: json['belt_rank']?.toString(),
      role: json['role'] ?? 'member',
      isActive: json['is_active'] ?? true,
      // Pas de plan en base (compte pas encore payé) → 'none', jamais
      // 'unlimited' (sinon tout non-payeur paraît illimité).
      subscriptionPlan: json['subscription_plan'] ?? 'none',
      weeklyBookingLimit: json['weekly_booking_limit'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'emergency_contact': emergencyContact,
      'avatar_url': avatarUrl,
      'belt_rank': beltRank,
      'role': role,
      'is_active': isActive,
      'subscription_plan': subscriptionPlan,
      'weekly_booking_limit': weeklyBookingLimit,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
