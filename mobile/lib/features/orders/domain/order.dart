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
    this.itemPhotoUrl,
    this.tripReturnDate,
    this.purchasedAt,
    this.shippedAt,
    this.shippingProofUrl,
    this.deliveredAt,
    this.canReview = false,
    this.myReview,
    this.travellerReward,
    this.shopperTotal,
    this.travellerPayout,
    this.currency,
  });

  final String id;
  final String shopperId;
  final String travelerId;
  final String itemDescription;
  final String totalPrice;
  final String fees;
  final String status;

  /// MVP pricing model split — null for orders created before it shipped;
  /// callers should fall back to [totalPrice]/[fees] in that case.
  final String? travellerReward;
  final String? shopperTotal;
  final String? travellerPayout;
  final String? currency;
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
  final String? itemPhotoUrl;

  /// The linked trip's return date — the deadline for uploading the item
  /// photo + receipt, from the traveler's point of view.
  final DateTime? tripReturnDate;
  final DateTime? purchasedAt;
  final DateTime? shippedAt;

  /// Optional evidence the traveler shipped the item — a photo with the
  /// courier (e.g. handed to a GrabBike rider) or a screenshot of the
  /// delivery app's booking page. Unlike the purchase receipt, this doesn't
  /// gate marking the order shipped.
  final String? shippingProofUrl;
  final DateTime? deliveredAt;
  final bool canReview;
  final OrderReview? myReview;

  String get totalLabel => money(totalPrice);
  String get feesLabel => money(fees);

  /// Whether this order has the pricing-model snapshot (created after
  /// migration 028) vs. an older order priced under the flat-fee model.
  bool get hasPricingBreakdown => travellerReward != null && shopperTotal != null && travellerPayout != null;
  String? get travellerRewardLabel => travellerReward == null ? null : money(travellerReward!);
  String? get shopperTotalLabel => shopperTotal == null ? null : money(shopperTotal!);
  String? get travellerPayoutLabel => travellerPayout == null ? null : money(travellerPayout!);

  /// Days left before the trip returns, floored at zero — null when there's
  /// no linked trip to count down to.
  int? get daysLeftToUpload {
    final deadline = tripReturnDate;
    if (deadline == null) return null;
    final hoursLeft = deadline.difference(DateTime.now()).inHours;
    return hoursLeft <= 0 ? 0 : (hoursLeft / 24).ceil();
  }

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
        itemPhotoUrl: (j['item_photo_url'] as String?)?.trim().isEmpty ?? true
            ? null
            : j['item_photo_url'] as String,
        tripReturnDate: parseDate(j['trip_return_date']),
        purchasedAt: parseDate(j['purchased_at']),
        shippedAt: parseDate(j['shipped_at']),
        shippingProofUrl: (j['shipping_proof_url'] as String?)?.trim().isEmpty ?? true
            ? null
            : j['shipping_proof_url'] as String,
        deliveredAt: parseDate(j['delivered_at']),
        canReview: j['can_review'] == true,
        myReview: j['my_review'] is Map
            ? OrderReview.fromJson(Map<String, dynamic>.from(j['my_review'] as Map))
            : null,
        travellerReward: _s(j['traveller_reward']),
        shopperTotal: _s(j['shopper_total']),
        travellerPayout: _s(j['traveller_payout']),
        currency: _s(j['currency']),
      );
}

String? _s(Object? v) {
  final s = v?.toString().trim() ?? '';
  return s.isEmpty ? null : s;
}
