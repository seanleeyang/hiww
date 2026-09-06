/// A short list of shopping destinations for the pilot. `code` is what the
/// backend stores (it accepts any non-empty string).
const kCountries = <({String code, String name})>[
  (code: 'JP', name: 'Japan'),
  (code: 'KR', name: 'South Korea'),
  (code: 'TH', name: 'Thailand'),
  (code: 'SG', name: 'Singapore'),
  (code: 'US', name: 'United States'),
  (code: 'GB', name: 'United Kingdom'),
  (code: 'FR', name: 'France'),
  (code: 'IT', name: 'Italy'),
  (code: 'DE', name: 'Germany'),
  (code: 'AU', name: 'Australia'),
  (code: 'CN', name: 'China'),
  (code: 'HK', name: 'Hong Kong'),
  (code: 'TW', name: 'Taiwan'),
  (code: 'MY', name: 'Malaysia'),
  (code: 'AE', name: 'United Arab Emirates'),
];

String countryName(String code) {
  for (final c in kCountries) {
    if (c.code == code) return c.name;
  }
  return code;
}

/// A likely-default city shown when a traveler leaves the city field blank —
/// skipped for countries too large to have one obvious hub (US, CN, AU), and
/// for JP, since the bundled Japan photo isn't a Tokyo landmark and this
/// label must not claim more specificity than the photo backs up.
const _defaultCities = <String, String>{
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
