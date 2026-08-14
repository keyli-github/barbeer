import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const themeModePreferenceKey = 'theme_mode';

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw StateError('SharedPreferences must be initialized in main'),
);

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((
  ref,
) {
  return ThemeModeNotifier(ref.watch(sharedPreferencesProvider));
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final SharedPreferences _preferences;

  ThemeModeNotifier(this._preferences)
    : super(_decode(_preferences.getString(themeModePreferenceKey)));

  Future<void> setMode(ThemeMode mode) async {
    if (state == mode) return;
    state = mode;
    await _preferences.setString(themeModePreferenceKey, mode.name);
  }

  static ThemeMode _decode(String? value) => switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}
