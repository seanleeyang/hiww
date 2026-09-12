import '../../../core/countries.dart';
import '../../../core/format.dart';
import '../../shared/domain/user_summary.dart';

class Trip {
  const Trip({
    required this.id,
    required this.travelerId,
    required this.departureCountry,
    required this.arrivalCountry,
    this.departureCity,
    this.arrivalCity,
    this.title,
    this.note,
    this.coverImageUrl,
    this.departureDate,
    this.returnDate,
    this.maxWeightKg = 0,
    this.maxItems = 0,
    this.status = 'published',
    this.createdAt,
  });

  final String id;
  final String travelerId;
  final String departureCountry;
  final String arrivalCountry;
  final String? departureCity;
  final String? arrivalCity;
  final String? title;
  final String? note;
  final String? coverImageUrl;
  final DateTime? departureDate;
  final DateTime? returnDate;
  final double maxWeightKg;
  final int maxItems;
  final String status;
  final DateTime? createdAt;

  /// [locale] is an [AppLocalizations.localeName] ('en' | 'th').
  String fromLabel([String locale = 'en']) =>
      departureCity ?? defaultCityFor(departureCountry) ?? countryName(departureCountry, locale);
  String toLabel([String locale = 'en']) =>
      arrivalCity ?? defaultCityFor(arrivalCountry) ?? countryName(arrivalCountry, locale);
  // "→" needs no translation, unlike the word "to" this replaced.
  String route([String locale = 'en']) => '${fromLabel(locale)} → ${toLabel(locale)}';
  String get dates => dateRange(departureDate, returnDate);

  factory Trip.fromJson(Map<String, dynamic> j) => Trip(
        id: j['id'].toString(),
        travelerId: j['traveler_id'].toString(),
        departureCountry: (j['departure_country'] ?? '').toString(),
        arrivalCountry: (j['arrival_country'] ?? '').toString(),
        departureCity: _s(j['departure_city']),
        arrivalCity: _s(j['arrival_city']),
        title: _s(j['title']),
        note: _s(j['note']),
        coverImageUrl: _s(j['cover_image_url']),
        departureDate: parseDate(j['departure_date']),
        returnDate: parseDate(j['return_date']),
        maxWeightKg: (j['max_weight_kg'] is String)
            ? double.tryParse(j['max_weight_kg'] as String) ?? 0
            : (j['max_weight_kg'] as num?)?.toDouble() ?? 0,
        maxItems: (j['max_items'] as num?)?.toInt() ?? 0,
        status: (j['status'] ?? 'published').toString(),
        createdAt: parseDate(j['created_at']),
      );
}

class TripDetail {
  const TripDetail({required this.trip, this.traveler});
  final Trip trip;
  final UserSummary? traveler;

  factory TripDetail.fromJson(Map<String, dynamic> j) => TripDetail(
        trip: Trip.fromJson(j),
        traveler: UserSummary.fromJson(j['traveler']),
      );
}

String? _s(Object? v) {
  final s = v?.toString().trim() ?? '';
  return s.isEmpty ? null : s;
}
