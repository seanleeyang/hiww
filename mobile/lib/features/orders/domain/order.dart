import '../../../core/format.dart';
import '../../shared/domain/user_summary.dart';

class OrderReview {
  const OrderReview({required this.rating, this.comment});
  final int rating;
  final String? comment;

  factory OrderReview.fromJson(Map<String, dynamic> j) => OrderReview(
        rating: (j['rating'] as num?)?.toInt() ?? 0,
        comment: j['comment'] as String?,
      );
}

class Order {
  const Order({
    required this.id,
    required this.shopperId,
    required this.travelerId,
    required this.itemDescription,
    required this.totalPrice,
    required this.fees,
    required this.status,
    this.counterparty,
    this.paymentClaimedAt,
    this.confirmedAt,
    this.shippedAt,
    this.deliveredAt,
    this.canReview = false,
    this.myReview,
  });

  final String id;
  final String shopperId;
  final String travelerId;
  final String itemDescription;
  final String totalPrice;
  final String fees;
  final String status;
  final UserSummary? counterparty;
  final DateTime? paymentClaimedAt;
  final DateTime? confirmedAt;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;
  final bool canReview;
  final OrderReview? myReview;

  String get totalLabel => money(totalPrice);
  String get feesLabel => money(fees);

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: j['id'].toString(),
        shopperId: j['shopper_id'].toString(),
        travelerId: j['traveler_id'].toString(),
        itemDescription: (j['item_description'] ?? '').toString(),
        totalPrice: (j['total_price'] ?? '0').toString(),
        fees: (j['fees'] ?? '0').toString(),
        status: (j['status'] ?? 'pending_payment').toString(),
        counterparty: UserSummary.fromJson(j['counterparty']),
        paymentClaimedAt: parseDate(j['payment_claimed_at']),
        confirmedAt: parseDate(j['confirmed_at']),
        shippedAt: parseDate(j['shipped_at']),
        deliveredAt: parseDate(j['delivered_at']),
        canReview: j['can_review'] == true,
        myReview: j['my_review'] is Map
            ? OrderReview.fromJson(Map<String, dynamic>.from(j['my_review'] as Map))
            : null,
      );
}
