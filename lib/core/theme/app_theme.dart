import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color primaryGreen = Color(0xFF63E6BE); // Copilot-ish Mint
  static const Color backgroundBlack = Color(0xFF000000);
  static const Color surfaceGrey = Color(0xFF1C1C1E);
  static const Color surfaceGreyLight = Color(0xFF2C2C2E);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textGrey = Color(0xFF8E8E93);

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryGreen,
      brightness: Brightness.dark,
      surface: surfaceGrey,
      onSurface: textWhite,
      primary: primaryGreen,
      secondary: const Color(0xFF5AC8FA), // Light Blue
      tertiary: const Color(0xFFFFCC00), // Yellow
      error: const Color(0xFFFF8B8B), // Pastel Red
    ),
    scaffoldBackgroundColor: backgroundBlack,
    cardColor: surfaceGrey,
    appBarTheme: const AppBarTheme(
      backgroundColor: backgroundBlack,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 80,
      titleSpacing: 24,
      centerTitle: false,
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
      bodyColor: textWhite,
      displayColor: textWhite,
    ),
    // cardTheme: CardTheme(
    //   color: surfaceGrey,
    //   elevation: 0,
    //   shape: RoundedRectangleBorder(
    //     borderRadius: BorderRadius.circular(16),
    //   ),
    // ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceGreyLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      hintStyle: const TextStyle(color: textGrey),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: backgroundBlack,
        backgroundColor: primaryGreen,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    ),
  );
}
