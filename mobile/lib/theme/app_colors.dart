import 'package:flutter/material.dart';

/// Brand colours that don't have a natural home in [ColorScheme].
/// Access with `Theme.of(context).extension<HiwwColors>()!`.
@immutable
class HiwwColors extends ThemeExtension<HiwwColors> {
  const HiwwColors({
    required this.success,
    required this.onSuccess,
    required this.successSurface,
    required this.star,
    required this.infoSurface,
    required this.hairline,
    required this.shadow,
  });

  final Color success;
  final Color onSuccess;
  final Color successSurface;
  final Color star;
  final Color infoSurface;
  final Color hairline;
  final Color shadow;

  static const light = HiwwColors(
    success: Color(0xFF2E9E6B),
    onSuccess: Color(0xFFFFFFFF),
    successSurface: Color(0xFFE4F3EB),
    star: Color(0xFFF4A62A),
    infoSurface: Color(0xFFF6EEE6),
    hairline: Color(0xFFECE4DD),
    shadow: Color(0x14000000),
  );

  static const dark = HiwwColors(
    success: Color(0xFF4CC08C),
    onSuccess: Color(0xFF06281A),
    successSurface: Color(0xFF1B3329),
    star: Color(0xFFF6B44A),
    infoSurface: Color(0xFF262019),
    hairline: Color(0xFF332D25),
    shadow: Color(0x33000000),
  );

  @override
  HiwwColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successSurface,
    Color? star,
    Color? infoSurface,
    Color? hairline,
    Color? shadow,
  }) {
    return HiwwColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successSurface: successSurface ?? this.successSurface,
      star: star ?? this.star,
      infoSurface: infoSurface ?? this.infoSurface,
      hairline: hairline ?? this.hairline,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  HiwwColors lerp(HiwwColors? other, double t) {
    if (other == null) return this;
    return HiwwColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successSurface: Color.lerp(successSurface, other.successSurface, t)!,
      star: Color.lerp(star, other.star, t)!,
      infoSurface: Color.lerp(infoSurface, other.infoSurface, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

/// Convenience getter.
extension HiwwColorsX on BuildContext {
  HiwwColors get hiww => Theme.of(this).extension<HiwwColors>()!;
}
