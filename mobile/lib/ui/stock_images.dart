/// Curated bundled imagery used as a fallback when a user hasn't supplied a
/// photo URL. Not for production — see docs/MOBILE.md.
library;

const _cities = <String, String>{
  'TH': 'assets/images/bangkok.jpg',
  'JP': 'assets/images/japan.jpg',
  'KR': 'assets/images/seoul.jpg',
  'GB': 'assets/images/london.jpg',
  'UK': 'assets/images/london.jpg',
  'TW': 'assets/images/taipei.jpg',
  'HK': 'assets/images/hongkong.jpg',
  'CN': 'assets/images/china.jpg',
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

const fallbackImage = 'assets/images/tokyo.jpg';

String stockForCountry(String? code) =>
    _cities[(code ?? '').toUpperCase()] ?? fallbackImage;

String stockForCategory(String? category) {
  final key = (category ?? '').toLowerCase().trim();
  return _categories[key] ?? fallbackImage;
}
