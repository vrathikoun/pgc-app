class Member {
  final int id;
  final String email;
  final String firstName;
  final String lastName;
  final String? phone;
  final String? avatarUrl;
  final String role;
  final bool isActive;
  final String subscriptionStatus;
  final DateTime createdAt;

  Member({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.avatarUrl,
    required this.role,
    required this.isActive,
    required this.subscriptionStatus,
    required this.createdAt,
  });

  factory Member.fromJson(Map<String, dynamic> json) => Member(
        id: json['id'],
        email: json['email'],
        firstName: json['first_name'],
        lastName: json['last_name'],
        phone: json['phone'],
        avatarUrl: json['avatar_url'],
        role: json['role'],
        isActive: json['is_active'],
        subscriptionStatus: json['subscription_status'],
        createdAt: DateTime.parse(json['created_at']),
      );

  String get fullName => '$firstName $lastName';
  bool get isAdmin => role == 'admin';
}