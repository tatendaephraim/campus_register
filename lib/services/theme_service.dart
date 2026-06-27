import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

enum AppThemeColor {
  indigo,
  rose,
  teal,
  amber,
  obsidian,
}

class ThemeSettings {
  final ThemeMode themeMode;
  final AppThemeColor themeColor;

  ThemeSettings({
    this.themeMode = ThemeMode.system,
    this.themeColor = AppThemeColor.indigo,
  });

  Color getSeedColor() {
    switch (themeColor) {
      case AppThemeColor.indigo:
        return const Color(0xFF6366F1);
      case AppThemeColor.rose:
        return const Color(0xFFF43F5E);
      case AppThemeColor.teal:
        return const Color(0xFF14B8A6);
      case AppThemeColor.amber:
        return const Color(0xFFF59E0B);
      case AppThemeColor.obsidian:
        return const Color(0xFF64748B);
    }
  }

  String getColorName() {
    switch (themeColor) {
      case AppThemeColor.indigo:
        return 'Precision Indigo';
      case AppThemeColor.rose:
        return 'Crimson Apex';
      case AppThemeColor.teal:
        return 'Teal Matrix';
      case AppThemeColor.amber:
        return 'Amber Vault';
      case AppThemeColor.obsidian:
        return 'Midnight Obsidian';
    }
  }

  ThemeSettings copyWith({
    ThemeMode? themeMode,
    AppThemeColor? themeColor,
  }) {
    return ThemeSettings(
      themeMode: themeMode ?? this.themeMode,
      themeColor: themeColor ?? this.themeColor,
    );
  }
}

class ThemeService {
  ThemeService._();
  static final ThemeService instance = ThemeService._();

  final ValueNotifier<ThemeSettings> settingsNotifier = ValueNotifier(ThemeSettings());

  Future<void> init() async {
    try {
      final file = await _getSettingsFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        
        final themeModeIndex = json['themeMode'] ?? ThemeMode.system.index;
        final themeColorIndex = json['themeColor'] ?? AppThemeColor.indigo.index;
        
        settingsNotifier.value = ThemeSettings(
          themeMode: ThemeMode.values[themeModeIndex],
          themeColor: AppThemeColor.values[themeColorIndex],
        );
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load theme settings: $e');
    }
  }

  Future<void> updateThemeMode(ThemeMode mode) async {
    settingsNotifier.value = settingsNotifier.value.copyWith(themeMode: mode);
    await _save();
  }

  Future<void> updateThemeColor(AppThemeColor color) async {
    settingsNotifier.value = settingsNotifier.value.copyWith(themeColor: color);
    await _save();
  }

  Future<void> _save() async {
    try {
      final file = await _getSettingsFile();
      final json = {
        'themeMode': settingsNotifier.value.themeMode.index,
        'themeColor': settingsNotifier.value.themeColor.index,
      };
      await file.writeAsString(jsonEncode(json));
    } catch (e) {
      debugPrint('⚠️ Failed to save theme settings: $e');
    }
  }

  Future<File> _getSettingsFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/.theme_settings');
  }
}
