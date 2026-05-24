import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Color token set for one palette (light or dark) ─────────────────
class AppColors {
  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color ink;
  final Color inkDim;
  final Color inkMute;
  final Color hairline;
  final Color hairlineSoft;
  final Color accent;
  final Color accentInk;
  final Color danger;

  const AppColors({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.ink,
    required this.inkDim,
    required this.inkMute,
    required this.hairline,
    required this.hairlineSoft,
    required this.accent,
    required this.accentInk,
    required this.danger,
  });
}

// ─── A named theme with light + dark palettes ─────────────────────────
class AppColorThemeDef {
  final String key;
  final String name;
  final String blurb;
  final AppColors light;
  final AppColors dark;

  const AppColorThemeDef({
    required this.key,
    required this.name,
    required this.blurb,
    required this.light,
    required this.dark,
  });
}

// ─── 8 pastel color themes ────────────────────────────────────────────
final Map<String, AppColorThemeDef> kAppColorThemes = {
  'mint': AppColorThemeDef(
    key: 'mint',
    name: 'Mint',
    blurb: 'Pale mint · deep teal',
    light: AppColors(
      bg: const Color(0xFFE6EDE7),
      surface: const Color(0xFFF0F4F0),
      surfaceAlt: const Color(0xFFD4DFD6),
      ink: const Color(0xFF0F1411),
      inkDim: const Color(0xFF566058),
      inkMute: const Color(0xFF9AA49B),
      hairline: const Color(0x1A0F1411),
      hairlineSoft: const Color(0x0D0F1411),
      accent: const Color(0xFF1B7A6B),
      accentInk: const Color(0xFFF0F4F0),
      danger: const Color(0xFFC04030),
    ),
    dark: AppColors(
      bg: const Color(0xFF0F1411),
      surface: const Color(0xFF181E1A),
      surfaceAlt: const Color(0xFF222823),
      ink: const Color(0xFFE6EDE7),
      inkDim: const Color(0xFF9AA49B),
      inkMute: const Color(0xFF566058),
      hairline: const Color(0x1AE6EDE7),
      hairlineSoft: const Color(0x0DE6EDE7),
      accent: const Color(0xFF7DCFC3),
      accentInk: const Color(0xFF0F1411),
      danger: const Color(0xFFD46050),
    ),
  ),
  'sky': AppColorThemeDef(
    key: 'sky',
    name: 'Sky',
    blurb: 'Pastel sky · deep cobalt',
    light: AppColors(
      bg: const Color(0xFFE2E8EF),
      surface: const Color(0xFFEDF1F6),
      surfaceAlt: const Color(0xFFCFD8E3),
      ink: const Color(0xFF0C111A),
      inkDim: const Color(0xFF525F70),
      inkMute: const Color(0xFF919EB0),
      hairline: const Color(0x1A0C111A),
      hairlineSoft: const Color(0x0D0C111A),
      accent: const Color(0xFF2B60AF),
      accentInk: const Color(0xFFEDF1F6),
      danger: const Color(0xFFC04030),
    ),
    dark: AppColors(
      bg: const Color(0xFF0C111A),
      surface: const Color(0xFF171D28),
      surfaceAlt: const Color(0xFF222A36),
      ink: const Color(0xFFE2E8EF),
      inkDim: const Color(0xFF919EB0),
      inkMute: const Color(0xFF525F70),
      hairline: const Color(0x1AE2E8EF),
      hairlineSoft: const Color(0x0DE2E8EF),
      accent: const Color(0xFF72A7E8),
      accentInk: const Color(0xFF0C111A),
      danger: const Color(0xFFD46050),
    ),
  ),
  'lavender': AppColorThemeDef(
    key: 'lavender',
    name: 'Lavender',
    blurb: 'Soft lavender · deep violet',
    light: AppColors(
      bg: const Color(0xFFEAE6EE),
      surface: const Color(0xFFF3F0F6),
      surfaceAlt: const Color(0xFFDAD3DF),
      ink: const Color(0xFF15101A),
      inkDim: const Color(0xFF5E5564),
      inkMute: const Color(0xFFA098A8),
      hairline: const Color(0x1A15101A),
      hairlineSoft: const Color(0x0D15101A),
      accent: const Color(0xFF7040B8),
      accentInk: const Color(0xFFF3F0F6),
      danger: const Color(0xFFC04030),
    ),
    dark: AppColors(
      bg: const Color(0xFF15101A),
      surface: const Color(0xFF1E1726),
      surfaceAlt: const Color(0xFF291F33),
      ink: const Color(0xFFEAE6EE),
      inkDim: const Color(0xFFA098A8),
      inkMute: const Color(0xFF5E5564),
      hairline: const Color(0x1AEAE6EE),
      hairlineSoft: const Color(0x0DEAE6EE),
      accent: const Color(0xFFB898F0),
      accentInk: const Color(0xFF15101A),
      danger: const Color(0xFFD46050),
    ),
  ),
  'rose': AppColorThemeDef(
    key: 'rose',
    name: 'Rose',
    blurb: 'Soft rose · deep wine',
    light: AppColors(
      bg: const Color(0xFFEFE5EA),
      surface: const Color(0xFFF6EEF2),
      surfaceAlt: const Color(0xFFE0D2D8),
      ink: const Color(0xFF190F12),
      inkDim: const Color(0xFF665058),
      inkMute: const Color(0xFFA8909A),
      hairline: const Color(0x1A190F12),
      hairlineSoft: const Color(0x0D190F12),
      accent: const Color(0xFF8B2050),
      accentInk: const Color(0xFFF6EEF2),
      danger: const Color(0xFFC04030),
    ),
    dark: AppColors(
      bg: const Color(0xFF190F12),
      surface: const Color(0xFF241A1D),
      surfaceAlt: const Color(0xFF2E2225),
      ink: const Color(0xFFEFE5EA),
      inkDim: const Color(0xFFA8909A),
      inkMute: const Color(0xFF665058),
      hairline: const Color(0x1AEFE5EA),
      hairlineSoft: const Color(0x0DEFE5EA),
      accent: const Color(0xFFD08090),
      accentInk: const Color(0xFF190F12),
      danger: const Color(0xFFD46050),
    ),
  ),
  'butter': AppColorThemeDef(
    key: 'butter',
    name: 'Butter',
    blurb: 'Pale butter · deep ochre',
    light: AppColors(
      bg: const Color(0xFFEEEAD8),
      surface: const Color(0xFFF5F2E3),
      surfaceAlt: const Color(0xFFDFD9C1),
      ink: const Color(0xFF161308),
      inkDim: const Color(0xFF605947),
      inkMute: const Color(0xFFA39B82),
      hairline: const Color(0x1A161308),
      hairlineSoft: const Color(0x0D161308),
      accent: const Color(0xFF706818),
      accentInk: const Color(0xFFF5F2E3),
      danger: const Color(0xFFC04030),
    ),
    dark: AppColors(
      bg: const Color(0xFF161308),
      surface: const Color(0xFF1F1B0F),
      surfaceAlt: const Color(0xFF2A2416),
      ink: const Color(0xFFEEEAD8),
      inkDim: const Color(0xFFA39B82),
      inkMute: const Color(0xFF605947),
      hairline: const Color(0x1AEEEAD8),
      hairlineSoft: const Color(0x0DEEEAD8),
      accent: const Color(0xFFD4C040),
      accentInk: const Color(0xFF161308),
      danger: const Color(0xFFD46050),
    ),
  ),
  'peach': AppColorThemeDef(
    key: 'peach',
    name: 'Peach',
    blurb: 'Pale peach · warm coral',
    light: AppColors(
      bg: const Color(0xFFF0E6DF),
      surface: const Color(0xFFF6EFE9),
      surfaceAlt: const Color(0xFFE2D3C7),
      ink: const Color(0xFF1A120C),
      inkDim: const Color(0xFF665850),
      inkMute: const Color(0xFFA8978A),
      hairline: const Color(0x1A1A120C),
      hairlineSoft: const Color(0x0D1A120C),
      accent: const Color(0xFFB85838),
      accentInk: const Color(0xFFF6EFE9),
      danger: const Color(0xFFC04030),
    ),
    dark: AppColors(
      bg: const Color(0xFF1A120C),
      surface: const Color(0xFF241A13),
      surfaceAlt: const Color(0xFF2E221A),
      ink: const Color(0xFFF0E6DF),
      inkDim: const Color(0xFFA8978A),
      inkMute: const Color(0xFF665850),
      hairline: const Color(0x1AF0E6DF),
      hairlineSoft: const Color(0x0DF0E6DF),
      accent: const Color(0xFFE0A060),
      accentInk: const Color(0xFF1A120C),
      danger: const Color(0xFFD46050),
    ),
  ),
  'sage': AppColorThemeDef(
    key: 'sage',
    name: 'Sage',
    blurb: 'Muted sage · deep moss',
    light: AppColors(
      bg: const Color(0xFFE8EBE2),
      surface: const Color(0xFFF1F3EC),
      surfaceAlt: const Color(0xFFD6DCCC),
      ink: const Color(0xFF11130D),
      inkDim: const Color(0xFF5A5E51),
      inkMute: const Color(0xFF9AA091),
      hairline: const Color(0x1A11130D),
      hairlineSoft: const Color(0x0D11130D),
      accent: const Color(0xFF3E6040),
      accentInk: const Color(0xFFF1F3EC),
      danger: const Color(0xFFC04030),
    ),
    dark: AppColors(
      bg: const Color(0xFF11130D),
      surface: const Color(0xFF1A1C15),
      surfaceAlt: const Color(0xFF23271D),
      ink: const Color(0xFFE8EBE2),
      inkDim: const Color(0xFF9AA091),
      inkMute: const Color(0xFF5A5E51),
      hairline: const Color(0x1AE8EBE2),
      hairlineSoft: const Color(0x0DE8EBE2),
      accent: const Color(0xFF88C080),
      accentInk: const Color(0xFF11130D),
      danger: const Color(0xFFD46050),
    ),
  ),
  'stone': AppColorThemeDef(
    key: 'stone',
    name: 'Stone',
    blurb: 'Cool stone · graphite',
    light: AppColors(
      bg: const Color(0xFFECECE9),
      surface: const Color(0xFFF5F5F2),
      surfaceAlt: const Color(0xFFDEDEDA),
      ink: const Color(0xFF101110),
      inkDim: const Color(0xFF5A5B58),
      inkMute: const Color(0xFF9B9C98),
      hairline: const Color(0x1A101110),
      hairlineSoft: const Color(0x0D101110),
      accent: const Color(0xFF101110),
      accentInk: const Color(0xFFF5F5F2),
      danger: const Color(0xFFC04030),
    ),
    dark: AppColors(
      bg: const Color(0xFF101110),
      surface: const Color(0xFF1A1B1A),
      surfaceAlt: const Color(0xFF242524),
      ink: const Color(0xFFECECE9),
      inkDim: const Color(0xFF9B9C98),
      inkMute: const Color(0xFF5A5B58),
      hairline: const Color(0x1AECECE9),
      hairlineSoft: const Color(0x0DECECE9),
      accent: const Color(0xFFECECE9),
      accentInk: const Color(0xFF101110),
      danger: const Color(0xFFD46050),
    ),
  ),
};

// ─── Active theme composed from key + dark flag ───────────────────────
class AppThemeData {
  final String themeKey;
  final bool isDark;
  final AppColors c;

  const AppThemeData({
    required this.themeKey,
    required this.isDark,
    required this.c,
  });

  AppColorThemeDef get def => kAppColorThemes[themeKey]!;
  String get name => def.name;

  static AppThemeData of(BuildContext context) {
    return AppThemeScope.of(context);
  }
}

// ─── InheritedWidget to provide AppThemeData down the tree ────────────
class AppThemeScope extends InheritedWidget {
  final AppThemeData appTheme;

  const AppThemeScope({
    super.key,
    required this.appTheme,
    required super.child,
  });

  static AppThemeData of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppThemeScope>();
    assert(scope != null, 'No AppThemeScope found in context');
    return scope!.appTheme;
  }

  @override
  bool updateShouldNotify(AppThemeScope old) =>
      old.appTheme.themeKey != appTheme.themeKey ||
      old.appTheme.isDark != appTheme.isDark;
}

// ─── Typography helpers ───────────────────────────────────────────────
TextStyle displayStyle({
  double fontSize = 18,
  FontWeight fontWeight = FontWeight.w500,
  Color? color,
  double letterSpacing = -0.4,
  double? height,
}) {
  return GoogleFonts.spaceGrotesk(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );
}

TextStyle bodyStyle({
  double fontSize = 14,
  FontWeight fontWeight = FontWeight.w400,
  Color? color,
  double letterSpacing = 0.1,
  double? height,
}) {
  return GoogleFonts.manrope(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );
}

TextStyle monoStyle({
  double fontSize = 13,
  FontWeight fontWeight = FontWeight.w400,
  Color? color,
  double letterSpacing = 0,
}) {
  return GoogleFonts.jetBrainsMono(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
  );
}

// ─── Build MaterialApp ThemeData from AppThemeData ───────────────────
ThemeData buildMaterialTheme(AppThemeData appTheme) {
  final c = appTheme.c;
  final brightness =
      appTheme.isDark ? Brightness.dark : Brightness.light;

  return ThemeData(
    brightness: brightness,
    scaffoldBackgroundColor: c.bg,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: c.accentInk,
      secondary: c.accent,
      onSecondary: c.accentInk,
      error: c.danger,
      onError: Colors.white,
      surface: c.surface,
      onSurface: c.ink,
    ),
    textTheme: GoogleFonts.manropeTextTheme().copyWith(
      displayLarge: displayStyle(fontSize: 57, fontWeight: FontWeight.w400),
      displayMedium: displayStyle(fontSize: 45, fontWeight: FontWeight.w400),
      displaySmall: displayStyle(fontSize: 36, fontWeight: FontWeight.w400),
      headlineLarge: displayStyle(fontSize: 32, fontWeight: FontWeight.w500),
      headlineMedium: displayStyle(fontSize: 28, fontWeight: FontWeight.w500),
      headlineSmall: displayStyle(fontSize: 24, fontWeight: FontWeight.w500),
      titleLarge: bodyStyle(fontSize: 22, fontWeight: FontWeight.w600),
      titleMedium: bodyStyle(fontSize: 16, fontWeight: FontWeight.w600),
      titleSmall: bodyStyle(fontSize: 14, fontWeight: FontWeight.w600),
      bodyLarge: bodyStyle(fontSize: 16, fontWeight: FontWeight.w400),
      bodyMedium: bodyStyle(fontSize: 14, fontWeight: FontWeight.w400),
      bodySmall: bodyStyle(fontSize: 12, fontWeight: FontWeight.w400),
      labelLarge: bodyStyle(fontSize: 14, fontWeight: FontWeight.w600),
      labelMedium: bodyStyle(fontSize: 12, fontWeight: FontWeight.w500),
      labelSmall: bodyStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.8),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      foregroundColor: c.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: displayStyle(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: c.ink,
      ),
    ),
    cardTheme: CardThemeData(
      color: c.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.accent,
      foregroundColor: c.accentInk,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(32),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: c.hairline,
      thickness: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      border: UnderlineInputBorder(
        borderSide: BorderSide(color: c.hairline),
      ),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: c.hairline),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: c.accent, width: 1.5),
      ),
      labelStyle: bodyStyle(fontSize: 11, color: c.inkMute, letterSpacing: 0.8),
      hintStyle: bodyStyle(color: c.inkMute),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: c.accent,
        foregroundColor: c.accentInk,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        textStyle: bodyStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.ink,
        textStyle: bodyStyle(fontSize: 15, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.ink,
      contentTextStyle: bodyStyle(color: c.bg),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
    ),
  );
}

// ─── Design token: corner radius ──────────────────────────────────────
const double kRadius = 20.0;

// ─── Design token: comfy density spacing ──────────────────────────────
const double kPad = 18.0;
const double kGap = 14.0;

// ─── Card shadow ──────────────────────────────────────────────────────
List<BoxShadow> cardShadow(bool isDark) {
  if (isDark) return [];
  return [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 0,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      blurRadius: 14,
      offset: const Offset(0, 4),
      spreadRadius: -10,
    ),
  ];
}

// ─── Bottom button area clearance ────────────────────────────────────
// The design keeps bottom CTAs ~44px above the bottom edge so they clear
// the Android gesture nav bar. We use this plus SafeArea's bottom inset.
const double kBottomClearance = 44.0;
