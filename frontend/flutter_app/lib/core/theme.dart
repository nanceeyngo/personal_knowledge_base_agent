import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ── Shared palette ─────────────────────────────────────────────────────────
  static const _primaryColor    = Color(0xFF6C63FF);
  static const _secondaryColor  = Color(0xFF00BFA5);
  static const _errorColor      = Color(0xFFB00020);

  // ── Dark palette ───────────────────────────────────────────────────────────
  static const _darkSurface     = Color(0xFF1E1E2E);
  static const _darkBackground  = Color(0xFF13131F);
  static const _darkCard        = Color(0xFF252538);

  // ── Light palette ──────────────────────────────────────────────────────────
  static const _lightBackground = Color(0xFFF4F4FB);
  static const _lightSurface    = Color(0xFFFFFFFF);
  static const _lightCard       = Color(0xFFEFEFF8);

  // ════════════════════════════════════════════════════════════════════════════
  // DARK THEME
  // ════════════════════════════════════════════════════════════════════════════
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: _primaryColor,
      secondary: _secondaryColor,
      error: _errorColor,
      surface: _darkSurface,
      onSurface: Colors.white,
      onPrimary: Colors.white,
    ),
    scaffoldBackgroundColor: _darkBackground,
    cardColor: _darkCard,
    textTheme:
    GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    appBarTheme: AppBarTheme(
      backgroundColor: _darkBackground,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.inter(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _darkSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
        const BorderSide(color: _primaryColor, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: Colors.white38),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(
            horizontal: 24, vertical: 14),
        textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: _darkSurface,
      labelStyle:
      GoogleFonts.inter(color: Colors.white70, fontSize: 12),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8)),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF2E2E42),
      thickness: 1,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: _primaryColor,
      foregroundColor: Colors.white,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: Colors.white54,
      textColor: Colors.black,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: _darkCard,
      contentTextStyle: GoogleFonts.inter(color: Colors.white),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
      behavior: SnackBarBehavior.floating,
    ),
  );

  // ════════════════════════════════════════════════════════════════════════════
  // LIGHT THEME
  // ════════════════════════════════════════════════════════════════════════════
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: _primaryColor,
      secondary: _secondaryColor,
      error: _errorColor,
      surface: _lightSurface,
      onSurface: Color(0xFF1A1A2E),
      onPrimary: Colors.white,
    ),
    scaffoldBackgroundColor: _lightBackground,
    cardColor: _lightSurface,
    textTheme:
    GoogleFonts.interTextTheme(ThemeData.light().textTheme),
    appBarTheme: AppBarTheme(
      backgroundColor: _lightSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.inter(
        color: const Color(0xFF1A1A2E),
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: const IconThemeData(color: Color(0xFF1A1A2E)),
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _lightCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
        const BorderSide(color: _primaryColor, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: Color(0xFF9E9EBA)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(
            horizontal: 24, vertical: 14),
        textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: _lightCard,
      labelStyle: GoogleFonts.inter(
          color: const Color(0xFF4A4A6A), fontSize: 12),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8)),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFE0E0F0),
      thickness: 1,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: _primaryColor,
      foregroundColor: Colors.white,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: Color(0xFF6B6B8E),
      textColor: Color(0xFF1A1A2E),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF1A1A2E),
      contentTextStyle: GoogleFonts.inter(color: Colors.white),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}