/// A short list of shopping destinations for the pilot. `code` is what the
/// backend stores (it accepts any non-empty string).
const kCountries = <({String code, String name})>[
  (code: 'JP', name: 'Japan'),
  (code: 'KR', name: 'South Korea'),
  (code: 'TH', name: 'Thailand'),
  (code: 'SG', name: 'Singapore'),
  (code: 'TW', name: 'Taiwan'),
  (code: 'HK', name: 'Hong Kong'),
  (code: 'CN', name: 'China'),
  (code: 'US', name: 'United States'),
  (code: 'GB', name: 'United Kingdom'),
  (code: 'FR', name: 'France'),
  (code: 'IT', name: 'Italy'),
  (code: 'DE', name: 'Germany'),
  (code: 'AU', name: 'Australia'),
  (code: 'MY', name: 'Malaysia'),
  (code: 'AE', name: 'United Arab Emirates'),
];

/// Phase 1 focuses on Asian routes we have real destination photos and
/// local knowledge for. The rest are still shown (as "coming soon") so the
/// roadmap is visible, but can't be selected for a new trip or want yet.
const _liveCodes = <String>{'JP', 'KR', 'TH', 'SG', 'TW', 'HK', 'CN'};

bool isLiveCountry(String code) => _liveCodes.contains(code.toUpperCase());

List<({String code, String name})> get kLiveCountries =>
    kCountries.where((c) => isLiveCountry(c.code)).toList();

List<({String code, String name})> get kComingSoonCountries =>
    kCountries.where((c) => !isLiveCountry(c.code)).toList();

String countryName(String code) {
  for (final c in kCountries) {
    if (c.code == code) return c.name;
  }
  return code;
}

/// A likely-default city shown when a traveler leaves the city field blank —
/// skipped for countries too large to have one obvious hub (US, CN, AU).
const _defaultCities = <String, String>{
  'JP': 'Tokyo',
  'KR': 'Seoul',
  'TH': 'Bangkok',
  'SG': 'Singapore',
  'GB': 'London',
  'FR': 'Paris',
  'IT': 'Milan',
  'DE': 'Frankfurt',
  'HK': 'Hong Kong',
  'TW': 'Taipei',
  'MY': 'Kuala Lumpur',
  'AE': 'Dubai',
};

String? defaultCityFor(String code) => _defaultCities[code.toUpperCase()];
