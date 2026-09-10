import 'cities.dart';

/// Empty-string sentinel for "nothing picked yet" — lets a dropdown show a
/// real "Select" placeholder entry instead of defaulting to a value.
const unselected = '';

/// Sentinel for "Others" in a city dropdown — reveals a free-text field for
/// a city not in the curated list.
const othersCity = '__others__';

/// Sentinel for "Any" in a city dropdown — a deliberate choice meaning no
/// specific city, distinct from [unselected] (no choice made).
const anyCity = '__any__';

/// Matches [city] against the curated list for [country]: an exact match
/// preselects that city, anything else preselects "Others" with the value
/// carried over into the custom field.
String initialCityChoice(String country, String? city) {
  if (city == null || city.isEmpty) return unselected;
  final matches = kCities.any(
    (c) => c.countryCode == country && c.city.toLowerCase() == city.toLowerCase(),
  );
  return matches ? city : othersCity;
}
