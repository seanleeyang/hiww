import 'world_countries.dart';

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
  (code: 'ES', name: 'Spain'),
  (code: 'CH', name: 'Switzerland'),
  (code: 'AT', name: 'Austria'),
  (code: 'DK', name: 'Denmark'),
  (code: 'NO', name: 'Norway'),
  (code: 'SE', name: 'Sweden'),
  (code: 'NL', name: 'Netherlands'),
  (code: 'BE', name: 'Belgium'),
  (code: 'AU', name: 'Australia'),
  (code: 'NZ', name: 'New Zealand'),
  (code: 'MY', name: 'Malaysia'),
  (code: 'AE', name: 'United Arab Emirates'),
];

/// Phase 1 focused on Asian routes we had real destination photos and local
/// knowledge for; USA, wider Europe, and Oceania (Australia/NZ) opened up in
/// Phase 2, alongside Malaysia. The rest are still shown (as "coming soon")
/// so the roadmap is visible, but can't be selected for a new trip or want
/// yet.
const _liveCodes = <String>{
  'JP', 'KR', 'TH', 'SG', 'TW', 'HK', 'CN', // Phase 1 — Asia
  'US', // Phase 2 — USA
  'GB', 'FR', 'IT', 'DE', 'ES', 'CH', 'AT', 'DK', 'NO', 'SE', 'NL', 'BE', // Phase 2 — Europe
  'MY', 'AU', 'NZ', // Phase 2 — Malaysia + Oceania
};

bool isLiveCountry(String code) => _liveCodes.contains(code.toUpperCase());

List<({String code, String name})> get kLiveCountries =>
    kCountries.where((c) => isLiveCountry(c.code)).toList();

List<({String code, String name})> get kComingSoonCountries =>
    kCountries.where((c) => !isLiveCountry(c.code)).toList();

/// [locale] is an [AppLocalizations.localeName] ('en' | 'th') — every code
/// in [kCountries] also exists in `kWorldCountries`, so its Thai name is
/// looked up there instead of duplicating a translation table here.
String countryName(String code, [String locale = 'en']) {
  final name = worldCountryName(code, locale);
  return name.isEmpty ? code : name;
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
  'ES': 'Barcelona',
  'CH': 'Zurich',
  'AT': 'Vienna',
  'DK': 'Copenhagen',
  'NO': 'Oslo',
  'SE': 'Stockholm',
  'NL': 'Amsterdam',
  'BE': 'Brussels',
  'NZ': 'Auckland',
};

String? defaultCityFor(String code) => _defaultCities[code.toUpperCase()];
