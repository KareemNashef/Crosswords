import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  Color _mainColor = Colors.blue;

  ThemeMode get themeMode => _themeMode;
  Color get mainColor => _mainColor;

  ThemeProvider() {
    loadFromPrefs();
  }

  void setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode.toString());
  }

  void setMainColor(Color color) async {
    _mainColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    // ignore: deprecated_member_use
    await prefs.setInt('mainColor', color.value);
  }

  Future loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final themeStr = prefs.getString('themeMode');
    final colorInt = prefs.getInt('mainColor');

    if (themeStr != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (e) => e.toString() == themeStr,
        orElse: () => ThemeMode.system,
      );
    }

    if (colorInt != null) {
      _mainColor = Color(colorInt);
    }

    notifyListeners();
  }
}
