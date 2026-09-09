/// Everything entered on the Create Order sheet, carried via go_router's
/// `extra` to `WantSummaryScreen` for review before the actual
/// `POST /api/requests` call.
class WantDraft {
  const WantDraft({
    this.productUrl,
    this.imageUrl,
    required this.title,
    required this.itemDescription,
    required this.category,
    required this.quantity,
    this.needBy,
    required this.sourceCountry,
    this.sourceCity,
    required this.destinationCountry,
    this.destinationCity,
    required this.budget,
    this.targetTripId,
    this.targetTravelerName,
  });

  final String? productUrl;
  final String? imageUrl;
  final String title;
  final String itemDescription;
  final String category;
  final int quantity;
  final DateTime? needBy;
  final String sourceCountry;
  final String? sourceCity;
  final String destinationCountry;
  final String? destinationCity;
  final int budget;
  final String? targetTripId;
  final String? targetTravelerName;

  bool get isDirectRequest => targetTripId != null;
}
