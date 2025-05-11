// Flutter imports
import 'package:flutter/material.dart';

// Theme provider
class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  Color _mainColor = Colors.blue;

  ThemeMode get themeMode => _themeMode;
  Color get mainColor => _mainColor;

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  void setMainColor(Color color) {
    _mainColor = color;
    notifyListeners();
  }
}
