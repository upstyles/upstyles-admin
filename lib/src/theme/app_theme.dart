import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors
  static const primaryColor = Color(0xFF6366F1);
  static const primaryLight = Color(0xFF818CF8);
  static const primaryDark = Color(0xFF4F46E5);
  static const accentColor = Color(0xFFA855F7);
  static const secondaryAccent = Color(0xFFEC4899);
  
  // Status Colors
  static const successColor = Color(0xFF10B981);
  static const errorColor = Color(0xFFEF4444);
  static const warningColor = Color(0xFFF59E0B);
  static const infoColor = Color(0xFF3B82F6);
  
  // Light Theme Colors
  static const surfaceColor = Color(0xFFF9FAFB);
  static const backgroundColor = Color(0xFFFFFFFF);
  static const cardColor = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textTertiary = Color(0xFF9CA3AF);
  static const dividerColor = Color(0xFFE5E7EB);
  
  // Dark Theme Colors
  static const darkSurfaceColor = Color(0xFF1F2937);
  static const darkBackgroundColor = Color(0xFF111827);
  static const darkCardColor = Color(0xFF374151);
  static const darkTextPrimary = Color(0xFFF9FAFB);
  static const darkTextSecondary = Color(0xFFD1D5DB);
  static const darkTextTertiary = Color(0xFF9CA3AF);
  static const darkDividerColor = Color(0xFF4B5563);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: primaryColor,
      secondary: accentColor,
      surface: surfaceColor,
      error: errorColor,
    ),
    scaffoldBackgroundColor: backgroundColor,
    cardColor: cardColor,
    dividerColor: dividerColor,
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: primaryLight,
      secondary: accentColor,
      surface: darkSurfaceColor,
      error: errorColor,
    ),
    scaffoldBackgroundColor: darkBackgroundColor,
    cardColor: darkCardColor,
    dividerColor: darkDividerColor,
  );
}
