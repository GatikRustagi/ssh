import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// AudiencePulse design system.
/// Aesthetic: Linear / Notion-inspired dark mode.
/// Primary palette: near-black background, violet accent, muted grays.
class AppTheme {
  AppTheme._();

  // ── Brand Colors ──────────────────────────────────────────────────────────
  static const Color background   = Color(0xFF0F0F0F);
  static const Color surface      = Color(0xFF101630);
  static const Color surfaceHigh  = Color(0xFF112564);
  static const Color border       = Color(0xFF1A2C5F);
  static const Color accent       = Color(0xFF1B2CC1);
  static const Color accentLight  = Color(0xFF7692FF);
  static const Color accentGlow   = Color(0x331B2CC1);

  static const Color textPrimary  = Color(0xFFF2F2F7);
  static const Color textSecondary = Color(0xFF8E8EA0);
  static const Color textMuted    = Color(0xFF52525E);

  // ── Sentiment Colors ──────────────────────────────────────────────────────
  static const Color sentimentPositive  = Color(0xFF4ADE80); // soft green
  static const Color sentimentNegative  = Color(0xFFF87171); // soft red
  static const Color sentimentNeutral   = Color(0xFF94A3B8); // soft slate
  static const Color sentimentSarcastic = Color(0xFFFBBF24); // soft amber
  static const Color sentimentAnxious   = Color(0xFFFB923C); // soft orange
  static const Color sentimentSupportive= Color(0xFF38BDF8); // soft blue
  static const Color sentimentAgainst   = Color(0xFFF472B6); // soft pink

  // ── Status Colors ─────────────────────────────────────────────────────────
  static const Color statusLive     = Color(0xFF22C55E);
  static const Color statusComingSoon = Color(0xFF52525E);

  // ── Text Theme ────────────────────────────────────────────────────────────
  static TextTheme _buildTextTheme() {
    return GoogleFonts.interTextTheme(
      const TextTheme(
        displayLarge:  TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: textPrimary),
        displayMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: textPrimary),
        displaySmall:  TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: textPrimary),
        headlineLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
        headlineMedium:TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
        headlineSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
        bodyLarge:     TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: textPrimary),
        bodyMedium:    TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: textSecondary),
        bodySmall:     TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: textMuted),
        labelLarge:    TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary),
        labelMedium:   TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textSecondary),
        labelSmall:    TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textMuted, letterSpacing: 0.5),
      ),
    );
  }

  // ── Main Theme ────────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        onPrimary: Color(0xFFFFFFFF),
        secondary: accentLight,
        onSecondary: Color(0xFFFFFFFF),
        surface: surface,
        onSurface: textPrimary,
        error: Color(0xFFEF4444),
        outline: border,
      ),
      textTheme: _buildTextTheme(),

      // Cards
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // App bar
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        iconTheme: const IconThemeData(color: textSecondary),
        surfaceTintColor: Colors.transparent,
      ),

      // Input fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHigh,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        hintStyle: const TextStyle(color: textMuted),
        labelStyle: const TextStyle(color: textSecondary),
      ),

      // Elevated buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      // Outlined buttons
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(color: border, thickness: 1, space: 0),

      // Dropdown
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceHigh,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: border),
          ),
        ),
      ),
    );
  }
}
