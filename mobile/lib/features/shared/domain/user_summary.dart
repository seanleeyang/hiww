/// Public profile + reputation slice returned by the backend on cards and
/// detail screens (`toUserSummary` in `src/utils/user-summary.ts`).
class UserSummary {
  const UserSummary({
    required this.id,
    required this.fullName,
    this.avatarUrl,
    this.homeCity,
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.deliveredCount = 0,
  });

  final String id;
  final String fullName;
  final String? avatarUrl;
  final String? homeCity;
  final double ratingAvg;
  final int ratingCount;
  final int deliveredCount;

  static UserSummary? fromJson(Object? json) {
    if (json is! Map) return null;
    return UserSummary(
      id: json['id'].toString(),
      fullName: (json['full_name'] ?? '').toString(),
      avatarUrl: _str(json['avatar_url']),
      homeCity: _str(json['home_city']),
      ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0,
      ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
      deliveredCount: (json['delivered_count'] as num?)?.toInt() ?? 0,
    );
  }
}

String? _str(Object? v) {
  final s = v?.toString().trim() ?? '';
  return s.isEmpty ? null : s;
}
