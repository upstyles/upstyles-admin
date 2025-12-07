import 'package:flutter/material.dart';

enum CustomTheme {
  indigo(Color(0xFF6366F1), 'Indigo'),
  purple(Color(0xFFA855F7), 'Purple'),
  pink(Color(0xFFEC4899), 'Pink'),
  red(Color(0xFFEF4444), 'Red'),
  orange(Color(0xFFF59E0B), 'Orange'),
  amber(Color(0xFFFBBF24), 'Amber'),
  green(Color(0xFF10B981), 'Green'),
  teal(Color(0xFF14B8A6), 'Teal'),
  cyan(Color(0xFF06B6D4), 'Cyan'),
  blue(Color(0xFF3B82F6), 'Blue'),
  slate(Color(0xFF64748B), 'Slate'),
  rose(Color(0xFFF43F5E), 'Rose');

  const CustomTheme(this.color, this.name);
  final Color color;
  final String name;
}

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  CustomTheme _selectedTheme = CustomTheme.indigo;

  ThemeMode get themeMode => _themeMode;
  CustomTheme get selectedTheme => _selectedTheme;
  Color get primaryColor => _selectedTheme.color;

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  void setTheme(CustomTheme theme) {
    _selectedTheme = theme;
    notifyListeners();
  }

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  ThemeData getLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _selectedTheme.color,
        brightness: Brightness.light,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
    );
  }

  ThemeData getDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _selectedTheme.color,
        brightness: Brightness.dark,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey[800]!, width: 1),
        ),
      ),
    );
  }
}
