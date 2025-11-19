import 'package:flutter/material.dart';

class MyColors {
  static const ColorScheme lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF121212),
    onPrimary: Colors.white,
    secondary: Color(0xFF8A9BA8),
    onSecondary: Colors.black,
    tertiary: Color(0xFF67B0A9),
    onTertiary: Colors.white,
    error: Color(0xFFB00020),
    onError: Colors.white,
    background: Color(0xFFF0F5F5),
    onBackground: Color(0xFF1A1A1A),
    surface: Color(0xFFE4ECEC),
    onSurface: Color(0xFF1A1A1A),
    surfaceVariant: Color(0xFFD3DFDF),
    onSurfaceVariant: Color(0xFF4A4A4A),
    outline: Color(0xFFB0B0B0),
  );

  static const ColorScheme darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color.fromARGB(255, 255, 255, 255),
    onPrimary: Colors.black,
    secondary: Color(0xFF67B0A9),
    onSecondary: Colors.black,
    tertiary: Color(0xFF4A5C6A),
    onTertiary: Colors.white,
    error: Color(0xFFCF6679),
    onError: Colors.black,
    background: Color(0xFF121212),
    onBackground: Color(0xFFE0E0E0),
    surface: Color(0xFF1E1E1E),
    onSurface: Color(0xFFE0E0E0),
    surfaceVariant: Color(0xFF2C2C2C),
    onSurfaceVariant: Color(0xFFB0B0B0),
    outline: Color(0xFF555555),
  );

  static const Color green = Colors.green;
  static const Color white = Colors.white;
  static const Color camo = Color.fromARGB(255, 193, 165, 165);
  static const Color grey = Color.fromARGB(255, 197, 197, 197);
  static const Color grey01 = Color.fromARGB(255, 39, 39, 39);
  static const Color red = Colors.red;
  static const Color backgund = Color.fromARGB(255, 13, 20, 17);
  static const Color foregund = Color.fromARGB(255, 19, 26, 25);
}
