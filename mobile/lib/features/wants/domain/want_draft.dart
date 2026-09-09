/// Everything entered on the Create Order form, carried via go_router's
/// `extra` from `CreateOrderScreen` to `WantSummaryScreen` for review before
/// the actual `POST /api/requests` call. Mirrors `TripQuickPrefill`'s role for
/// `/trips/new`.
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

/// Prefill passed into `/wants/new` for "Request from this trip" — mirrors
/// `TripQuickPrefill`'s role for `/trips/new`.
class PostWantPrefill {
  const PostWantPrefill({
    this.sourceCountry,
    this.sourceCity,
    this.targetTripId,
    this.targetTravelerName,
  });

  final String? sourceCountry;
  final String? sourceCity;
  final String? targetTripId;
  final String? targetTravelerName;
}
