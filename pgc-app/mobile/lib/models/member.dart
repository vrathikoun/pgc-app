class Member {
  final int id;
  final String email;
  final String firstName;
  final String lastName;
  final String? phone;
  final String? avatarUrl;
  final String? beltRank;
  final String role;
  final bool isActive;
  final String subscriptionStatus;
  final DateTime? createdAt;

  Member({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.avatarUrl,
    this.beltRank,
    required this.role,
    required this.isActive,
    required this.subscriptionStatus,
    this.createdAt,
  });

  String get fullName => '$firstName $lastName';

  bool get isAdmin => role == 'admin';
  bool get isCoach => role == 'coach' || role == 'admin';

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'],
      email: json['email'],
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      phone: json['phone'],
      avatarUrl: json['avatar_url'],
      beltRank: json['belt_rank'],
      role: json['role'] ?? 'member',
      isActive: json['is_active'] ?? true,
      subscriptionStatus: json['subscription_status'] ?? 'inactive',
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
      'avatar_url': avatarUrl,
      'belt_rank': beltRank,
      'role': role,
      'is_active': isActive,
      'subscription_status': subscriptionStatus,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}