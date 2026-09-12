import '../../../core/format.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/domain/user_summary.dart';

class Want {
  const Want({
    required this.id,
    required this.shopperId,
    required this.itemDescription,
    required this.sourceCountry,
    required this.category,
    required this.budget,
    this.quantity = 1,
    this.title,
    this.sourceCity,
    this.imageUrl,
    this.needBy,
    this.status = 'open',
    this.createdAt,
    this.targetTripId,
    this.destinationCountry,
    this.destinationCity,
    this.productUrl,
  });

  final String id;
  final String shopperId;
  final String itemDescription;
  final String sourceCountry;
  final String category;
  final String budget;
  final int quantity;
  final String? title;
  final String? sourceCity;
  final String? imageUrl;
  final DateTime? needBy;
  final String status;
  final DateTime? createdAt;

  /// Delivery destination — distinct from sourceCountry/sourceCity (where to
  /// buy the item). Required on new wants; may be null on wants created
  /// before this field existed.
  final String? destinationCountry;
  final String? destinationCity;
  final String? productUrl;

  /// Set when this want was sent directly to one trip's traveler ("Request
  /// from this trip") — never shown in public browse.
  final String? targetTripId;
  bool get isDirectRequest => targetTripId != null;

  String get displayTitle =>
      (title != null && title!.isNotEmpty) ? title! : itemDescription;
  String get sourceLabel => sourceCity ?? sourceCountry;
  String? get destinationLabel => destinationCity ?? destinationCountry;
  String get budgetLabel => money(budget);
  String? needByLabel(AppLocalizations l10n) =>
      needBy == null ? null : l10n.needByDate(shortDate(l10n, needBy));

  factory Want.fromJson(Map<String, dynamic> j) => Want(
        id: j['id'].toString(),
        shopperId: j['shopper_id'].toString(),
        itemDescription: (j['item_description'] ?? '').toString(),
        sourceCountry: (j['source_country'] ?? '').toString(),
        category: (j['category'] ?? '').toString(),
        budget: (j['budget'] ?? '0').toString(),
        quantity: (j['quantity'] as num?)?.toInt() ?? 1,
        title: _s(j['title']),
        sourceCity: _s(j['source_city']),
        imageUrl: _s(j['image_url']),
        needBy: parseDate(j['need_by']),
        status: (j['status'] ?? 'open').toString(),
        createdAt: parseDate(j['created_at']),
        targetTripId: _s(j['target_trip_id']),
        destinationCountry: _s(j['destination_country']),
        destinationCity: _s(j['destination_city']),
        productUrl: _s(j['product_url']),
      );
}

class WantDetail {
  const WantDetail({required this.want, this.shopper});
  final Want want;
  final UserSummary? shopper;

  factory WantDetail.fromJson(Map<String, dynamic> j) => WantDetail(
        want: Want.fromJson(j),
        shopper: UserSummary.fromJson(j['shopper']),
      );
}

String? _s(Object? v) {
  final s = v?.toString().trim() ?? '';
  return s.isEmpty ? null : s;
}
