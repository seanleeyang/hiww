import 'countries.dart' as countries;

/// A small curated set of real cities for the countries this pilot
/// currently supports (`kLiveCountries` in `countries.dart`) — enough for
/// the "Traveling from/to" search sheet to have real results, without
/// needing a full geocoding dataset/service the app has no other use for.
class CityOption {
  const CityOption({required this.city, required this.countryCode, required this.countryName});
  final String city;
  final String countryCode;

  /// English country name, kept only for [searchCities]' text matching.
  /// Display text should go through [countryLabel]/[label] instead, which
  /// follow the app's language toggle — the city name itself stays as
  /// written here either way (transliterating city names accurately into
  /// Thai is a separate, much bigger dataset this pilot's short curated
  /// list doesn't attempt).
  final String countryName;

  /// [locale] is an [AppLocalizations.localeName] ('en' | 'th').
  String countryLabel([String locale = 'en']) => countries.countryName(countryCode, locale);

  String label([String locale = 'en']) => '$city, ${countryLabel(locale)}';
}

const kCities = <CityOption>[
  CityOption(city: 'Tokyo', countryCode: 'JP', countryName: 'Japan'),
  CityOption(city: 'Osaka', countryCode: 'JP', countryName: 'Japan'),
  CityOption(city: 'Kyoto', countryCode: 'JP', countryName: 'Japan'),
  CityOption(city: 'Fukuoka', countryCode: 'JP', countryName: 'Japan'),
  CityOption(city: 'Sapporo', countryCode: 'JP', countryName: 'Japan'),
  CityOption(city: 'Seoul', countryCode: 'KR', countryName: 'South Korea'),
  CityOption(city: 'Busan', countryCode: 'KR', countryName: 'South Korea'),
  CityOption(city: 'Bangkok', countryCode: 'TH', countryName: 'Thailand'),
  CityOption(city: 'Chiang Mai', countryCode: 'TH', countryName: 'Thailand'),
  CityOption(city: 'Phuket', countryCode: 'TH', countryName: 'Thailand'),
  CityOption(city: 'Singapore', countryCode: 'SG', countryName: 'Singapore'),
  CityOption(city: 'Taipei', countryCode: 'TW', countryName: 'Taiwan'),
  CityOption(city: 'Kaohsiung', countryCode: 'TW', countryName: 'Taiwan'),
  CityOption(city: 'Hong Kong', countryCode: 'HK', countryName: 'Hong Kong'),
  CityOption(city: 'Shanghai', countryCode: 'CN', countryName: 'China'),
  CityOption(city: 'Beijing', countryCode: 'CN', countryName: 'China'),
  CityOption(city: 'Guangzhou', countryCode: 'CN', countryName: 'China'),
  CityOption(city: 'Shenzhen', countryCode: 'CN', countryName: 'China'),
  CityOption(city: 'Chongqing', countryCode: 'CN', countryName: 'China'),
  CityOption(city: 'Chengdu', countryCode: 'CN', countryName: 'China'),
];

List<CityOption> searchCities(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return kCities;
  return kCities
      .where((c) => c.city.toLowerCase().contains(q) || c.countryName.toLowerCase().contains(q))
      .toList();
}
