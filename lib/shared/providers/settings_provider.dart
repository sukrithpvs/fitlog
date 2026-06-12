// lib/shared/providers/settings_provider.dart
// Global settings providers — theme mode and weight unit preferences.
// Uses Riverpod 3.x Notifier pattern (StateNotifier was removed in v3).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import 'package:drift/drift.dart' show Value;

// ─── Theme Mode Provider ───
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _loadTheme();
    return ThemeMode.dark; // default until DB loads
  }

  AppDatabase get _db => ref.read(databaseProvider);

  Future<void> _loadTheme() async {
    final settings = await _db.getSettings();
    state = settings.themeMode == 'light' ? ThemeMode.light : ThemeMode.dark;
  }

  Future<void> toggleTheme() async {
    final newMode = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = newMode;
    await _db.updateSettings(
      UserSettingsCompanion(
        themeMode: Value(newMode == ThemeMode.dark ? 'dark' : 'light'),
      ),
    );
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    await _db.updateSettings(
      UserSettingsCompanion(
        themeMode: Value(mode == ThemeMode.dark ? 'dark' : 'light'),
      ),
    );
  }
}

// ─── Weight Unit Provider ───
final weightUnitProvider = NotifierProvider<WeightUnitNotifier, String>(
  WeightUnitNotifier.new,
);

class WeightUnitNotifier extends Notifier<String> {
  @override
  String build() {
    _loadUnit();
    return 'kg'; // default until DB loads
  }

  AppDatabase get _db => ref.read(databaseProvider);

  Future<void> _loadUnit() async {
    final settings = await _db.getSettings();
    state = settings.weightUnit;
  }

  Future<void> toggleUnit() async {
    final newUnit = state == 'kg' ? 'lbs' : 'kg';
    state = newUnit;
    await _db.updateSettings(
      UserSettingsCompanion(weightUnit: Value(newUnit)),
    );
  }
}

// ─── Rest Timer Default Provider ───
final defaultRestSecondsProvider = NotifierProvider<DefaultRestNotifier, int>(
  DefaultRestNotifier.new,
);

class DefaultRestNotifier extends Notifier<int> {
  @override
  int build() {
    _load();
    return 90; // default until DB loads
  }

  AppDatabase get _db => ref.read(databaseProvider);

  Future<void> _load() async {
    final settings = await _db.getSettings();
    state = settings.defaultRestSeconds;
  }

  Future<void> setDuration(int seconds) async {
    state = seconds;
    await _db.updateSettings(
      UserSettingsCompanion(defaultRestSeconds: Value(seconds)),
    );
  }
}
