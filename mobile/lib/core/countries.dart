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
