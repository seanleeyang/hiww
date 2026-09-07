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
    this.requestId,
    this.counterparty,
    this.requestImageUrl,
    this.requestCategory,
    this.createdAt,
    this.paymentClaimedAt,
    this.paymentDeadlineAt,
    this.cancelledAt,
    this.confirmedAt,
    this.purchaseProofUrl,
    this.purchasedAt,
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
  final String? requestId;
  final UserSummary? counterparty;
  final String? requestImageUrl;
  final String? requestCategory;
  final DateTime? createdAt;
  final DateTime? paymentClaimedAt;

  /// Order auto-cancels if payment isn't claimed by this time.
  final DateTime? paymentDeadlineAt;
  final DateTime? cancelledAt;
  final DateTime? confirmedAt;
  final String? purchaseProofUrl;
  final DateTime? purchasedAt;
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
        requestId: j['request_id']?.toString(),
        counterparty: UserSummary.fromJson(j['counterparty']),
        requestImageUrl: (j['request_image_url'] as String?)?.trim().isEmpty ?? true
            ? null
            : j['request_image_url'] as String,
        requestCategory: j['request_category']?.toString(),
        createdAt: parseDate(j['created_at']),
        paymentClaimedAt: parseDate(j['payment_claimed_at']),
        paymentDeadlineAt: parseDate(j['payment_deadline_at']),
        cancelledAt: parseDate(j['cancelled_at']),
        confirmedAt: parseDate(j['confirmed_at']),
        purchaseProofUrl: (j['purchase_proof_url'] as String?)?.trim().isEmpty ?? true
            ? null
            : j['purchase_proof_url'] as String,
        purchasedAt: parseDate(j['purchased_at']),
        shippedAt: parseDate(j['shipped_at']),
        deliveredAt: parseDate(j['delivered_at']),
        canReview: j['can_review'] == true,
        myReview: j['my_review'] is Map
            ? OrderReview.fromJson(Map<String, dynamic>.from(j['my_review'] as Map))
            : null,
      );
}
