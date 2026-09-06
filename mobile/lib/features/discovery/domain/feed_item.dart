import '../../shared/domain/user_summary.dart';
import '../../trips/domain/trip.dart';
import '../../wants/domain/want.dart';

/// One card in the Browse feed — either a traveler's trip or a shopper's want.
class FeedItem {
  const FeedItem({
    required this.kind,
    required this.id,
    this.trip,
    this.want,
    this.owner,
    this.matchCount = 0,
    this.earnMin,
    this.earnMax,
  });

  final String kind; // 'trip' | 'want'
  final String id;
  final Trip? trip;
  final Want? want;
  final UserSummary? owner;
  final int matchCount;

  /// Per-item commission range across this trip's currently matched wants —
  /// what carrying any one of them would pay, not a sum (a trip can't
  /// fulfil every match at once, so a total would overstate the upside).
  final String? earnMin;
  final String? earnMax;

  bool get isTrip => kind == 'trip';

  factory FeedItem.fromJson(Map<String, dynamic> j) {
    final kind = (j['kind'] ?? '').toString();
    return FeedItem(
      kind: kind,
      id: j['id'].toString(),
      trip: j['trip'] is Map
          ? Trip.fromJson(Map<String, dynamic>.from(j['trip'] as Map))
          : null,
      want: j['request'] is Map
          ? Want.fromJson(Map<String, dynamic>.from(j['request'] as Map))
          : null,
      owner: UserSummary.fromJson(j['traveler'] ?? j['shopper']),
      matchCount: (j['match_count'] as num?)?.toInt() ?? 0,
      earnMin: _nonEmpty(j['earn_min']),
      earnMax: _nonEmpty(j['earn_max']),
    );
  }
}

String? _nonEmpty(Object? v) {
  final s = (v as String?)?.trim();
  return (s == null || s.isEmpty) ? null : s;
}
