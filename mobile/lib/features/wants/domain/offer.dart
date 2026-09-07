import '../../../core/format.dart';

/// One price proposed during a negotiation — `by` is 'traveler' or 'shopper'.
class PriceHistoryEntry {
  const PriceHistoryEntry({required this.by, required this.price, this.at});
  final String by;
  final String price;
  final DateTime? at;

  factory PriceHistoryEntry.fromJson(Map<String, dynamic> j) => PriceHistoryEntry(
        by: (j['by'] ?? '').toString(),
        price: (j['price'] ?? '0').toString(),
        at: parseDate(j['at']),
      );
}

class Offer {
  const Offer({
    required this.id,
    required this.quotedPrice,
    this.deliveryDate,
    this.status = 'pending',
    this.travelerId,
    this.travelerName,
    this.tripId,
    this.createdAt,
    this.requestId,
    this.requestItem,
    this.requestStatus,
    this.round = 0,
    this.lastActor,
    this.respondBy,
    this.myTurn = false,
    this.canCounter = false,
    this.priceHistory = const [],
    this.myRole,
    this.counterpartyName,
  });

  final String id;
  final String quotedPrice;
  final DateTime? deliveryDate;
  final String status;

  // Present on `GET /api/requests/:id/offers`
  final String? travelerId;
  final String? travelerName;
  final String? tripId;
  final DateTime? createdAt;

  // Present on `GET /api/offers/mine`
  final String? requestId;
  final String? requestItem;
  final String? requestStatus;

  /// Negotiation state — capped at 2 counters total (see backend
  /// `config.maxOfferCounters`). `lastActor` is who proposed the current
  /// price; `myTurn`/`canCounter` are computed server-side for the caller.
  final int round;
  final String? lastActor;
  final DateTime? respondBy;
  final bool myTurn;
  final bool canCounter;
  final List<PriceHistoryEntry> priceHistory;

  // Present on `GET /api/offers/negotiations` — the unified view merges
  // both roles, so each item says which one the caller is playing here.
  final String? myRole;
  final String? counterpartyName;

  String get priceLabel => money(quotedPrice);
  String? get deliveryLabel =>
      deliveryDate == null ? null : 'Deliver by ${shortDate(deliveryDate)}';
  bool get isNegotiating => status == 'pending' && round > 0;

  factory Offer.fromJson(Map<String, dynamic> j) => Offer(
        id: j['id'].toString(),
        quotedPrice: (j['quoted_price'] ?? '0').toString(),
        deliveryDate: parseDate(j['delivery_date']),
        status: (j['status'] ?? 'pending').toString(),
        travelerId: j['traveler_id']?.toString(),
        travelerName: j['traveler_name']?.toString(),
        tripId: j['trip_id']?.toString(),
        createdAt: parseDate(j['created_at']),
        requestId: j['request_id']?.toString(),
        requestItem: j['request_item']?.toString(),
        requestStatus: j['request_status']?.toString(),
        round: (j['round'] as num?)?.toInt() ?? 0,
        lastActor: j['last_actor']?.toString(),
        respondBy: parseDate(j['respond_by']),
        myTurn: j['my_turn'] == true,
        canCounter: j['can_counter'] == true,
        priceHistory: (j['price_history'] as List?)
                ?.map((e) => PriceHistoryEntry.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
        myRole: j['my_role']?.toString(),
        counterpartyName: j['counterparty_name']?.toString(),
      );
}
