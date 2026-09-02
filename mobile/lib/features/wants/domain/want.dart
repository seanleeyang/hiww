import '../../../core/format.dart';
import '../../shared/domain/user_summary.dart';

class Want {
  const Want({
    required this.id,
    required this.shopperId,
    required this.itemDescription,
    required this.sourceCountry,
    required this.category,
    required this.budget,
    this.title,
    this.sourceCity,
    this.imageUrl,
    this.needBy,
    this.status = 'open',
    this.createdAt,
  });

  final String id;
  final String shopperId;
  final String itemDescription;
  final String sourceCountry;
  final String category;
  final String budget;
  final String? title;
  final String? sourceCity;
  final String? imageUrl;
  final DateTime? needBy;
  final String status;
  final DateTime? createdAt;

  String get displayTitle =>
      (title != null && title!.isNotEmpty) ? title! : itemDescription;
  String get sourceLabel => sourceCity ?? sourceCountry;
  String get budgetLabel => money(budget);
  String? get needByLabel => needBy == null ? null : 'Need by ${shortDate(needBy)}';

  factory Want.fromJson(Map<String, dynamic> j) => Want(
        id: j['id'].toString(),
        shopperId: j['shopper_id'].toString(),
        itemDescription: (j['item_description'] ?? '').toString(),
        sourceCountry: (j['source_country'] ?? '').toString(),
        category: (j['category'] ?? '').toString(),
        budget: (j['budget'] ?? '0').toString(),
        title: _s(j['title']),
        sourceCity: _s(j['source_city']),
        imageUrl: _s(j['image_url']),
        needBy: parseDate(j['need_by']),
        status: (j['status'] ?? 'open').toString(),
        createdAt: parseDate(j['created_at']),
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
