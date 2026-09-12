import 'countries.dart' as countries;

/// A small curated set of real cities for the countries this pilot
/// currently supports (`kLiveCountries` in `countries.dart`) — enough for
/// the "Traveling from/to" search sheet to have real results, without
/// needing a full geocoding dataset/service the app has no other use for.
class CityOption {
  const CityOption({required this.city, required this.cityTh, required this.countryCode, required this.countryName});
  final String city;

  /// Standard Thai transliteration of [city] — shown instead of [city] when
  /// the app's locale is Thai (see [cityLabel]/[label]).
  final String cityTh;
  final String countryCode;

  /// English country name, kept only for [searchCities]' text matching.
  /// Display text should go through [countryLabel]/[label] instead, which
  /// follow the app's language toggle.
  final String countryName;

  /// [locale] is an [AppLocalizations.localeName] ('en' | 'th').
  String cityLabel([String locale = 'en']) => locale == 'th' ? cityTh : city;
  String countryLabel([String locale = 'en']) => countries.countryName(countryCode, locale);

  String label([String locale = 'en']) => '${cityLabel(locale)}, ${countryLabel(locale)}';
}

const kCities = <CityOption>[
  CityOption(city: 'Tokyo', cityTh: 'โตเกียว', countryCode: 'JP', countryName: 'Japan'),
  CityOption(city: 'Osaka', cityTh: 'โอซาก้า', countryCode: 'JP', countryName: 'Japan'),
  CityOption(city: 'Kyoto', cityTh: 'เกียวโต', countryCode: 'JP', countryName: 'Japan'),
  CityOption(city: 'Fukuoka', cityTh: 'ฟุกุโอกะ', countryCode: 'JP', countryName: 'Japan'),
  CityOption(city: 'Sapporo', cityTh: 'ซัปโปโร', countryCode: 'JP', countryName: 'Japan'),
  CityOption(city: 'Seoul', cityTh: 'โซล', countryCode: 'KR', countryName: 'South Korea'),
  CityOption(city: 'Busan', cityTh: 'ปูซาน', countryCode: 'KR', countryName: 'South Korea'),
  CityOption(city: 'Bangkok', cityTh: 'กรุงเทพฯ', countryCode: 'TH', countryName: 'Thailand'),
  CityOption(city: 'Chiang Mai', cityTh: 'เชียงใหม่', countryCode: 'TH', countryName: 'Thailand'),
  CityOption(city: 'Phuket', cityTh: 'ภูเก็ต', countryCode: 'TH', countryName: 'Thailand'),
  CityOption(city: 'Singapore', cityTh: 'สิงคโปร์', countryCode: 'SG', countryName: 'Singapore'),
  CityOption(city: 'Taipei', cityTh: 'ไทเป', countryCode: 'TW', countryName: 'Taiwan'),
  CityOption(city: 'Kaohsiung', cityTh: 'เกาสง', countryCode: 'TW', countryName: 'Taiwan'),
  CityOption(city: 'Hong Kong', cityTh: 'ฮ่องกง', countryCode: 'HK', countryName: 'Hong Kong'),
  CityOption(city: 'Shanghai', cityTh: 'เซี่ยงไฮ้', countryCode: 'CN', countryName: 'China'),
  CityOption(city: 'Beijing', cityTh: 'ปักกิ่ง', countryCode: 'CN', countryName: 'China'),
  CityOption(city: 'Guangzhou', cityTh: 'กว่างโจว', countryCode: 'CN', countryName: 'China'),
  CityOption(city: 'Shenzhen', cityTh: 'เสิ่นเจิ้น', countryCode: 'CN', countryName: 'China'),
  CityOption(city: 'Chongqing', cityTh: 'ฉงชิ่ง', countryCode: 'CN', countryName: 'China'),
  CityOption(city: 'Chengdu', cityTh: 'เฉิงตู', countryCode: 'CN', countryName: 'China'),
];

List<CityOption> searchCities(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return kCities;
  return kCities
      .where((c) =>
          c.city.toLowerCase().contains(q) ||
          c.cityTh.contains(q) ||
          c.countryName.toLowerCase().contains(q))
      .toList();
}
