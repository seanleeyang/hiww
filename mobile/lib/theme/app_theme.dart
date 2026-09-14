import 'package:flutter/material.dart';

import 'app_colors.dart';

const _fontFamily = 'PlusJakartaSans';

/// Radii used across the app.
class HiwwRadii {
  static const card = 20.0;
  static const sheet = 28.0;
  static const input = 14.0;
  static const button = 16.0;
}

// Brand refresh (2026-09-14): Tangelo / Linen / Chocolate Brown / Botticelli,
// adopted from a reference palette the founder liked. Only the primary/
// neutral families shift — secondary (success green), tertiary (gold) and
// error keep their prior hues, which were never part of this swap.
const _lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFFFB4D00), // Tangelo
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFFFEDE3), // Linen
  onPrimaryContainer: Color(0xFF49261D), // Chocolate Brown
  secondary: Color(0xFF2E9E6B),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFE4F3EB),
  onSecondaryContainer: Color(0xFF17402D),
  tertiary: Color(0xFFB7791F),
  onTertiary: Color(0xFFFFFFFF),
  tertiaryContainer: Color(0xFFFBEBD0),
  onTertiaryContainer: Color(0xFF5A3B0B),
  error: Color(0xFFC7412C),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFF9E0DB),
  onErrorContainer: Color(0xFF5F1B10),
  surface: Color(0xFFFFFFFF),
  onSurface: Color(0xFF49261D), // Chocolate Brown
  // Darkened slightly past a literal Chocolate-Brown tint so muted text
  // clears 4.5:1 against Linen (~5.15:1) rather than landing at ~4.06:1 —
  // the prior palette had this same near-miss; worth fixing while this
  // exact value is already being touched for the swap.
  onSurfaceVariant: Color(0xFF7A5F53),
  surfaceContainerLowest: Color(0xFFFFFFFF),
  surfaceContainerLow: Color(0xFFFFEDE3), // Linen
  surfaceContainer: Color(0xFFFAE3D5),
  surfaceContainerHigh: Color(0xFFF5D6C3),
  surfaceContainerHighest: Color(0xFFECD9D0),
  outline: Color(0xFFD9BCAC),
  outlineVariant: Color(0xFFECD9D0),
  inverseSurface: Color(0xFF3A2015),
  onInverseSurface: Color(0xFFFFEDE3),
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
);

const _darkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFFFF8659), // lightened Tangelo, for text/fills on dark
  onPrimary: Color(0xFF3A1C0D),
  primaryContainer: Color(0xFF6B3016),
  onPrimaryContainer: Color(0xFFFFDFC9),
  secondary: Color(0xFF4CC08C),
  onSecondary: Color(0xFF06281A),
  secondaryContainer: Color(0xFF184433),
  onSecondaryContainer: Color(0xFFCDEEDD),
  tertiary: Color(0xFFE0B675),
  onTertiary: Color(0xFF3E2A08),
  tertiaryContainer: Color(0xFF5A3B0B),
  onTertiaryContainer: Color(0xFFFBEBD0),
  error: Color(0xFFF28C79),
  onError: Color(0xFF4A150C),
  errorContainer: Color(0xFF6B2318),
  onErrorContainer: Color(0xFFF9E0DB),
  surface: Color(0xFF1F130D), // Chocolate-Brown-derived dark, not neutral gray
  onSurface: Color(0xFFF7ECE4),
  onSurfaceVariant: Color(0xFFBFA99C),
  surfaceContainerLowest: Color(0xFF150D08),
  surfaceContainerLow: Color(0xFF1F130D),
  surfaceContainer: Color(0xFF261A12),
  surfaceContainerHigh: Color(0xFF2E2016),
  surfaceContainerHighest: Color(0xFF382819),
  outline: Color(0xFF5C4634),
  outlineVariant: Color(0xFF3D2E22),
  inverseSurface: Color(0xFFF7ECE4),
  onInverseSurface: Color(0xFF1F130D),
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
);

TextTheme _textTheme(ColorScheme scheme) {
  final base = Typography.material2021().black.apply(
        fontFamily: _fontFamily,
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      );
  return base.copyWith(
    headlineMedium: base.headlineMedium?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    ),
    headlineSmall: base.headlineSmall?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
    ),
    titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    bodyLarge: base.bodyLarge?.copyWith(height: 1.45),
    bodyMedium: base.bodyMedium?.copyWith(height: 1.45),
  );
}

ThemeData hiwwTheme(Brightness brightness) {
  final scheme = brightness == Brightness.dark ? _darkScheme : _lightScheme;
  final ext = brightness == Brightness.dark ? HiwwColors.dark : HiwwColors.light;
  final text = _textTheme(scheme);

  OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(HiwwRadii.input),
        borderSide: BorderSide(color: color, width: width),
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surfaceContainerLow,
    fontFamily: _fontFamily,
    textTheme: text,
    extensions: [ext],
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
      foregroundColor: scheme.onSurface,
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HiwwRadii.card),
        side: BorderSide(color: ext.hairline),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide(color: ext.hairline),
      backgroundColor: scheme.surface,
      selectedColor: scheme.primary,
      labelStyle: text.labelLarge,
      secondaryLabelStyle: text.labelLarge?.copyWith(color: scheme.onPrimary),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: border(ext.hairline),
      enabledBorder: border(ext.hairline),
      focusedBorder: border(scheme.primary, 1.5),
      errorBorder: border(scheme.error),
      focusedErrorBorder: border(scheme.error, 1.5),
      hintStyle: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        textStyle: text.labelLarge?.copyWith(fontSize: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HiwwRadii.button),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: scheme.primary,
        side: BorderSide(color: scheme.primary.withValues(alpha: 0.5)),
        textStyle: text.labelLarge?.copyWith(fontSize: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HiwwRadii.button),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: scheme.primary),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primaryContainer,
      elevation: 0,
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => text.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? scheme.onPrimaryContainer
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
      selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
      unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      selectedLabelTextStyle: text.labelMedium?.copyWith(
        color: scheme.primary,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle:
          text.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(HiwwRadii.sheet)),
      ),
    ),
    dividerTheme: DividerThemeData(color: ext.hairline, thickness: 1, space: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: text.bodyMedium?.copyWith(color: scheme.onInverseSurface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    ),
  );
}
