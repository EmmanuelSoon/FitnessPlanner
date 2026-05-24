import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

// ─── Persisted theme state ────────────────────────────────────────────
class ThemeState {
  final String themeKey;
  final bool isDark;

  const ThemeState({
    this.themeKey = 'mint',
    this.isDark = false,
  });

  ThemeState copyWith({String? themeKey, bool? isDark}) => ThemeState(
        themeKey: themeKey ?? this.themeKey,
        isDark: isDark ?? this.isDark,
      );

  AppThemeData get appThemeData {
    final def = kAppColorThemes[themeKey] ?? kAppColorThemes['mint']!;
    return AppThemeData(
      themeKey: themeKey,
      isDark: isDark,
      c: isDark ? def.dark : def.light,
    );
  }
}

class ThemeNotifier extends AsyncNotifier<ThemeState> {
  static const _keyTheme = 'theme_key';
  static const _keyDark = 'theme_dark';

  @override
  Future<ThemeState> build() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_keyTheme) ?? 'mint';
    final dark = prefs.getBool(_keyDark) ?? false;
    return ThemeState(themeKey: key, isDark: dark);
  }

  Future<void> setThemeKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTheme, key);
    state = AsyncData(state.value!.copyWith(themeKey: key));
  }

  Future<void> setDark(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDark, isDark);
    state = AsyncData(state.value!.copyWith(isDark: isDark));
  }
}

final themeProvider = AsyncNotifierProvider<ThemeNotifier, ThemeState>(
  ThemeNotifier.new,
);
