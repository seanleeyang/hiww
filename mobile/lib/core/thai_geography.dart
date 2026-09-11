import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Thailand's province → district (amphoe) → sub-district (tambon) →
/// postal code hierarchy, for the address picker on Personal Information.
/// Sourced once at MIT-licensed `thailand-geography-data/thailand-geography-json`
/// and bundled as JSON assets — loaded lazily and cached in memory since the
/// sub-district table alone is ~7,400 rows.
class ThaiProvince {
  const ThaiProvince({required this.code, required this.nameEn, required this.nameTh});
  final int code;
  final String nameEn;
  final String nameTh;
}

class ThaiDistrict {
  const ThaiDistrict({
    required this.code,
    required this.provinceCode,
    required this.nameEn,
    required this.nameTh,
    required this.postalCode,
  });
  final int code;
  final int provinceCode;
  final String nameEn;
  final String nameTh;
  final String postalCode;
}

class ThaiSubdistrict {
  const ThaiSubdistrict({
    required this.code,
    required this.districtCode,
    required this.nameEn,
    required this.nameTh,
    required this.postalCode,
  });
  final int code;
  final int districtCode;
  final String nameEn;
  final String nameTh;
  final String postalCode;
}

class ThaiGeography {
  ThaiGeography._({required this.provinces, required this.districts, required this.subdistricts});

  final List<ThaiProvince> provinces;
  final List<ThaiDistrict> districts;
  final List<ThaiSubdistrict> subdistricts;

  static Future<ThaiGeography>? _future;

  static Future<ThaiGeography> load() {
    return _future ??= _load();
  }

  static Future<ThaiGeography> _load() async {
    final results = await Future.wait([
      rootBundle.loadString('assets/data/th_provinces.json'),
      rootBundle.loadString('assets/data/th_districts.json'),
      rootBundle.loadString('assets/data/th_subdistricts.json'),
    ]);

    final provinces = (jsonDecode(results[0]) as List)
        .cast<Map<String, dynamic>>()
        .map((j) => ThaiProvince(
              code: j['provinceCode'] as int,
              nameEn: j['provinceNameEn'] as String,
              nameTh: j['provinceNameTh'] as String,
            ))
        .toList(growable: false);

    final districts = (jsonDecode(results[1]) as List)
        .cast<Map<String, dynamic>>()
        .map((j) => ThaiDistrict(
              code: j['districtCode'] as int,
              provinceCode: j['provinceCode'] as int,
              nameEn: j['districtNameEn'] as String,
              nameTh: j['districtNameTh'] as String,
              postalCode: j['postalCode'].toString(),
            ))
        .toList(growable: false);

    final subdistricts = (jsonDecode(results[2]) as List)
        .cast<Map<String, dynamic>>()
        .map((j) => ThaiSubdistrict(
              code: j['subdistrictCode'] as int,
              districtCode: j['districtCode'] as int,
              nameEn: j['subdistrictNameEn'] as String,
              nameTh: j['subdistrictNameTh'] as String,
              postalCode: j['postalCode'].toString(),
            ))
        .toList(growable: false);

    return ThaiGeography._(provinces: provinces, districts: districts, subdistricts: subdistricts);
  }

  List<ThaiDistrict> districtsFor(int provinceCode) =>
      districts.where((d) => d.provinceCode == provinceCode).toList(growable: false);

  List<ThaiSubdistrict> subdistrictsFor(int districtCode) =>
      subdistricts.where((s) => s.districtCode == districtCode).toList(growable: false);

  ThaiProvince? provinceByName(String name) {
    final n = name.trim().toLowerCase();
    if (n.isEmpty) return null;
    for (final p in provinces) {
      if (p.nameEn.toLowerCase() == n || p.nameTh == name.trim()) return p;
    }
    return null;
  }

  ThaiDistrict? districtByName(int provinceCode, String name) {
    final n = name.trim().toLowerCase();
    if (n.isEmpty) return null;
    for (final d in districtsFor(provinceCode)) {
      if (d.nameEn.toLowerCase() == n || d.nameTh == name.trim()) return d;
    }
    return null;
  }

  ThaiSubdistrict? subdistrictByName(int districtCode, String name) {
    final n = name.trim().toLowerCase();
    if (n.isEmpty) return null;
    for (final s in subdistrictsFor(districtCode)) {
      if (s.nameEn.toLowerCase() == n || s.nameTh == name.trim()) return s;
    }
    return null;
  }
}
