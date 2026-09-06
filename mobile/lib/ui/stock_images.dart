/// Curated bundled imagery used as a fallback when a user hasn't supplied a
/// photo URL. Not for production — see docs/MOBILE.md.
library;

/// Matched first, against the trip's actual city — real, verified landmark
/// photos. Keep keys lowercase; lookup trims/lowercases the input.
const _cityImages = <String, String>{
  'tokyo': 'assets/images/tokyo.jpg',
  'osaka': 'assets/images/osaka.jpg',
  'fukuoka': 'assets/images/fukuoka.jpg',
  'shanghai': 'assets/images/shanghai.jpg',
  'beijing': 'assets/images/beijing.jpg',
  'chengdu': 'assets/images/chengdu.jpg',
  'bangkok': 'assets/images/bangkok.jpg',
  'seoul': 'assets/images/seoul.jpg',
  'taipei': 'assets/images/taipei.jpg',
  'hong kong': 'assets/images/hongkong.jpg',
  'singapore': 'assets/images/singapore.jpg',
};

/// Fallback when the trip has no city, or a city we don't have a photo for —
/// one representative photo per country. No entry for GB/UK yet: the only
/// photo we had for London didn't actually depict London, so it's better to
/// fall through to the neutral placeholder than show the wrong city.
const _countryImages = <String, String>{
  'TH': 'assets/images/bangkok.jpg',
  'JP': 'assets/images/tokyo.jpg',
  'KR': 'assets/images/seoul.jpg',
  'TW': 'assets/images/taipei.jpg',
  'HK': 'assets/images/hongkong.jpg',
  'CN': 'assets/images/shanghai.jpg',
  'SG': 'assets/images/singapore.jpg',
};

const _categories = <String, String>{
  'beauty': 'assets/images/beauty.jpg',
  'skincare': 'assets/images/beauty.jpg',
  'sneakers': 'assets/images/sneakers.jpg',
  'shoes': 'assets/images/sneakers.jpg',
  'electronics': 'assets/images/electronics.jpg',
  'tech': 'assets/images/electronics.jpg',
  'fashion': 'assets/images/fashion.jpg',
  'clothing': 'assets/images/fashion.jpg',
};

/// Generic, no-landmark scenery — used only when neither the city nor the
/// country has a verified photo. Never claims to depict a specific place.
const fallbackImage = 'assets/images/placeholder.jpg';

/// City takes priority over country: a Japan trip landing in Osaka should
/// show Osaka, not the generic Japan/Tokyo photo.
String stockForTrip({String? city, String? countryCode}) {
  final cityKey = (city ?? '').trim().toLowerCase();
  if (cityKey.isNotEmpty && _cityImages.containsKey(cityKey)) {
    return _cityImages[cityKey]!;
  }
  return _countryImages[(countryCode ?? '').toUpperCase()] ?? fallbackImage;
}

String stockForCategory(String? category) {
  final key = (category ?? '').toLowerCase().trim();
  return _categories[key] ?? fallbackImage;
}
