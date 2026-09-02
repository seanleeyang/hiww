import '../../../core/format.dart';

class RouteMatchTrip {
  const RouteMatchTrip({
    required this.id,
    required this.travelerName,
    required this.departureCountry,
    required this.arrivalCountry,
    this.departureCity,
    this.arrivalCity,
    this.departureDate,
    this.returnDate,
  });

  final String id;
  final String travelerName;
  final String departureCountry;
  final String arrivalCountry;
  final String? departureCity;
  final String? arrivalCity;
  final DateTime? departureDate;
  final DateTime? returnDate;

  String get route =>
      '${departureCity ?? departureCountry} → ${arrivalCity ?? arrivalCountry}';

  factory RouteMatchTrip.fromJson(Map<String, dynamic> j) => RouteMatchTrip(
        id: j['id'].toString(),
        travelerName: (j['traveler_name'] ?? '').toString(),
        departureCountry: (j['departure_country'] ?? '').toString(),
        arrivalCountry: (j['arrival_country'] ?? '').toString(),
        departureCity: j['departure_city']?.toString(),
        arrivalCity: j['arrival_city']?.toString(),
        departureDate: parseDate(j['departure_date']),
        returnDate: parseDate(j['return_date']),
      );
}

class RouteMatch {
  const RouteMatch({required this.count, required this.sample});

  final int count;
  final List<RouteMatchTrip> sample;

  factory RouteMatch.fromJson(Map<String, dynamic> j) => RouteMatch(
        count: (j['count'] as num?)?.toInt() ?? 0,
        sample: ((j['sample'] as List?) ?? [])
            .map((e) => RouteMatchTrip.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}
