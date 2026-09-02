/// Roles a user can sign up as. Mirrors the backend `users.user_type` enum.
enum UserType {
  shopper,
  traveler,
  both;

  static UserType parse(Object? value) => UserType.values.firstWhere(
        (t) => t.name == value,
        orElse: () => UserType.shopper,
      );

  bool get isShopper => this == UserType.shopper || this == UserType.both;
  bool get isTraveler => this == UserType.traveler || this == UserType.both;
}

/// Pilot flags surfaced by `GET /api/me`.
class PilotInfo {
  const PilotInfo({required this.manualMoney, required this.paymentInstructions});

  final bool manualMoney;
  final String paymentInstructions;

  factory PilotInfo.fromJson(Map<String, dynamic> json) => PilotInfo(
        manualMoney: json['manual_money'] == true,
        paymentInstructions: (json['payment_instructions'] ?? '').toString(),
      );
}

/// The signed-in user, as returned by `GET /api/me`.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.userType,
    required this.role,
    required this.kycStatus,
    required this.riskStatus,
    this.avatarUrl,
    this.homeCity,
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.deliveredCount = 0,
    this.pilot,
  });

  final String id;
  final String email;
  final String fullName;
  final UserType userType;
  final String role;
  final String kycStatus;
  final String riskStatus;

  /// Profile + reputation — populated once the backend supports it (phase D2).
  final String? avatarUrl;
  final String? homeCity;
  final double ratingAvg;
  final int ratingCount;
  final int deliveredCount;

  final PilotInfo? pilot;

  bool get isAdmin => role == 'admin';
  bool get isKycApproved => kycStatus == 'approved';

  String get firstName {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty || parts.first.isEmpty ? 'there' : parts.first;
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'].toString(),
        email: (json['email'] ?? '').toString(),
        fullName: (json['full_name'] ?? '').toString(),
        userType: UserType.parse(json['user_type']),
        role: (json['role'] ?? 'user').toString(),
        kycStatus: (json['kyc_status'] ?? 'pending').toString(),
        riskStatus: (json['risk_status'] ?? 'clear').toString(),
        avatarUrl: (json['avatar_url'] as String?)?.trim().isEmpty ?? true
            ? null
            : json['avatar_url'] as String,
        homeCity: json['home_city'] as String?,
        ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0,
        ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
        deliveredCount: (json['delivered_count'] as num?)?.toInt() ?? 0,
        pilot: json['pilot'] is Map
            ? PilotInfo.fromJson(Map<String, dynamic>.from(json['pilot'] as Map))
            : null,
      );
}
