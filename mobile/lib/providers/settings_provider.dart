import 'package:flutter/material.dart';

class SettingsProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  String _appLanguage = 'en';

  ThemeMode get themeMode => _themeMode;
  String get appLanguage => _appLanguage;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void setLanguage(String langCode) {
    _appLanguage = langCode;
    notifyListeners();
  }
}