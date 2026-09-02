import '../../../core/format.dart';

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

  String get priceLabel => money(quotedPrice);
  String? get deliveryLabel =>
      deliveryDate == null ? null : 'Deliver by ${shortDate(deliveryDate)}';

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
      );
}
