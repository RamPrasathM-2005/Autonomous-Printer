import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// AppTheme — Precision Utility aesthetic
// Blue accents, white cards, and a soft tiled page background.
// ---------------------------------------------------------------------------

class AppTheme {
  // ── Core Palette ──────────────────────────────────────────────────────────
  static const Color primary      = Color(0xFF1A56DB); // True ink blue
  static const Color primaryDark  = Color(0xFF1447AE);
  static const Color primaryLight = Color(0xFF4A80E8);

  // Blue surface tints
  static const Color primarySurface = Color(0xFFF0F5FF);
  static const Color primaryBorder  = Color(0xFFBFCFEF);

  // ── Neutral Surfaces ──────────────────────────────────────────────────────
  static const Color bgCanvas     = Color(0xFFF7F8FA); // page canvas
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFF2F4F7);
  static const Color surfaceLight  = Color(0xFFEAECF0);

  // ── Borders ───────────────────────────────────────────────────────────────
  static const Color border        = Color(0xFFDDE1E7);
  static const Color borderFocus   = Color(0xFF1A56DB);

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFF0D1117); // near-black
  static const Color textSecondary = Color(0xFF4B5563);
  static const Color textMuted     = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Colors.white;

  // ── Semantic Colors ───────────────────────────────────────────────────────
  static const Color success        = Color(0xFF059669);
  static const Color successSurface = Color(0xFFF0FDF4);
  static const Color successBorder  = Color(0xFFA7F3D0);

  static const Color warning        = Color(0xFFD97706);
  static const Color warningSurface = Color(0xFFFFFBEB);
  static const Color warningBorder  = Color(0xFFFCD34D);

  static const Color danger         = Color(0xFFDC2626);
  static const Color dangerSurface  = Color(0xFFFEF2F2);
  static const Color dangerBorder   = Color(0xFFFCA5A5);

  // Legacy aliases for backward compat
  static const Color accent         = primary;
  static const Color accentSurface  = primarySurface;
  static const Color secondary      = Color(0xFF0D1117);
  static const Color infoBorder     = primaryBorder;
  static const Color infoBg         = primarySurface;
  static const Color infoSurface    = primarySurface;
  static const Color info           = primary;
  static const Color successBg      = successSurface;
  static const Color warningBg      = warningSurface;
  static const Color dangerBg       = dangerSurface;
  static const Color borderSubtle   = surfaceLight;
  static const Color borderFocused  = borderFocus;
  static const Color bgLight        = bgCanvas;
  static const Color surfaceDark    = Color(0xFF111827);
  static const Color cardDark       = Color(0xFF0D1117);

  // ── Shadows ───────────────────────────────────────────────────────────────
  // Refined multi-layer shadows for soft, tactile depth
  static final List<BoxShadow> cardShadow = [
    BoxShadow(
      color: const Color(0xFF0D1117).withValues(alpha: 0.04),
      blurRadius: 14,
      spreadRadius: 0,
      offset: const Offset(0, 3),
    ),
    BoxShadow(
      color: const Color(0xFF0D1117).withValues(alpha: 0.02),
      blurRadius: 4,
      spreadRadius: 0,
      offset: const Offset(0, 1),
    ),
  ];

  static final List<BoxShadow> hoverShadow = [
    BoxShadow(
      color: const Color(0xFF1A56DB).withValues(alpha: 0.12),
      blurRadius: 16,
      spreadRadius: 0,
      offset: const Offset(0, 5),
    ),
    BoxShadow(
      color: const Color(0xFF0D1117).withValues(alpha: 0.04),
      blurRadius: 6,
      spreadRadius: 0,
      offset: const Offset(0, 2),
    ),
  ];

  static final List<BoxShadow> buttonShadow = [
    BoxShadow(
      color: primary.withValues(alpha: 0.22),
      blurRadius: 10,
      spreadRadius: 0,
      offset: const Offset(0, 3),
    ),
  ];

  static final List<BoxShadow> accentShadow = buttonShadow;

  // ── Gradients (use sparingly — buttons only) ──────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1A56DB), Color(0xFF1447AE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Legacy aliases
  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF111827), Color(0xFF0D1117)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = primaryGradient;
  static const LinearGradient subtleGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF7F8FA)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── Material ThemeData ────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      brightness: Brightness.light,
      scaffoldBackgroundColor: bgCanvas,
      primaryColor: primary,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: Color(0xFF0D1117),
        surface: surfaceWhite,
        error: danger,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
      ),
      cardTheme: CardThemeData(
        color: surfaceWhite,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 16.5,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: textPrimary, size: 20),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.1),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceWhite,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDDE1E7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.8),
        ),
        hintStyle: const TextStyle(color: textMuted, fontSize: 14),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 13.5),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceWhite,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE2E8F0),
        thickness: 1,
        space: 1,
      ),
    );
  }
}
