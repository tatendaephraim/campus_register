// Campus Register — Design Tokens
//
// Single source of truth for color, type, spacing, and shape across the app.
// The visual identity is built around the product's actual subject: a
// precision verification system (volumetric geofencing, altitude sensing,
// biometric binding). Type and color choices favor an instrument-grade,
// technical feel over a generic SaaS look.
//
// Type pairing:
//  - Display / headings: Space Grotesk — geometric, confident, slightly
//    technical without being cold. Used with restraint, for titles and
//    the few numbers/labels that should command attention.
//  - Body / UI text: Inter — humanist, highly legible at small sizes,
//    the workhorse for lists, forms, and descriptions.
//  - Data / measurements: JetBrains Mono — for anything that is
//    literally a measurement or code: coordinates, altitude, timestamps,
//    device IDs, registration codes. Monospacing makes columns of
//    numbers scannable and signals "this is raw data, trust it."
//
// Color: the app already converged on an indigo/slate palette. We keep
// that (it suits "precision + calm authority") but formalize it as named
// tokens instead of scattering literal hex values through every screen.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand and semantic color tokens.
class AppColors {
  AppColors._();

  // Brand
  static const Color indigo = Color(0xFF6366F1);
  static const Color indigoDark = Color(0xFF4F46E5);
  static const Color indigoLight = Color(0xFF818CF8);
  static const Color indigoDeep = Color(0xFF1E1B4B);

  // Secondary accent — used sparingly for "live / active" cues
  static const Color teal = Color(0xFF14B8A6);
  static const Color tealLight = Color(0xFF2DD4BF);
  static const Color sky = Color(0xFF0EA5E9);
  static const Color amber = Color(0xFFF59E0B);
  static const Color amberLight = Color(0xFFFBBF24);

  // Status
  static const Color success = Color(0xFF10B981);
  static const Color successDark = Color(0xFF059669);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFF43F5E);
  static const Color dangerDark = Color(0xFFE11D48);

  // Slate neutrals (light surface)
  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate900 = Color(0xFF0F172A);
  static const Color slate950 = Color(0xFF020617);

  // Convenience semantic aliases (resolve per-brightness in helpers below)
  static Color textPrimary(bool isDark) => isDark ? Colors.white : slate800;
  static Color textSecondary(bool isDark) => isDark ? slate400 : slate500;
  static Color textTertiary(bool isDark) => isDark ? slate500 : slate400;
  static Color surface(bool isDark) => isDark ? slate800 : Colors.white;
  static Color surfaceMuted(bool isDark) => isDark ? slate900 : slate50;
  static Color border(bool isDark) =>
      isDark ? Colors.white.withValues(alpha: 0.08) : slate200;
  static Color scrim(bool isDark) =>
      isDark ? Colors.black.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.06);
}

/// Spacing scale — use these instead of ad-hoc magic numbers for new code.
class AppSpace {
  AppSpace._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;
}

/// Corner radius scale — keeps the pill/rounded language consistent.
class AppRadius {
  AppRadius._();
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 22;
  static const double pill = 999;
  static BorderRadius get smR => BorderRadius.circular(sm);
  static BorderRadius get mdR => BorderRadius.circular(md);
  static BorderRadius get lgR => BorderRadius.circular(lg);
  static BorderRadius get xlR => BorderRadius.circular(xl);
}

/// Typography helpers. Call these instead of raw GoogleFonts.* calls so
/// every screen stays in sync if the type system changes later.
class AppType {
  AppType._();

  /// Display/heading face — Space Grotesk.
  static TextStyle display(
    BuildContext context, {
    double? fontSize,
    FontWeight weight = FontWeight.w600,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.spaceGrotesk(
      fontSize: fontSize,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Body/UI face — Inter.
  static TextStyle body(
    BuildContext context, {
    double? fontSize,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Data/measurement face — JetBrains Mono. Use for coordinates,
  /// altitude readings, device IDs, registration codes, timestamps.
  static TextStyle data(
    BuildContext context, {
    double? fontSize,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double? letterSpacing,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  /// Builds a full TextTheme for ThemeData using the display/body pairing.
  static TextTheme textTheme(Brightness brightness) {
    final base = brightness == Brightness.dark
        ? Typography.material2021().white
        : Typography.material2021().black;

    final display = GoogleFonts.spaceGroteskTextTheme(base);
    final body = GoogleFonts.interTextTheme(base);

    return body.copyWith(
      displayLarge: display.displayLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -1.5),
      displayMedium: display.displayMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -1.0),
      displaySmall: display.displaySmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.5),
      headlineLarge: display.headlineLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -1.0),
      headlineMedium: display.headlineMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.6),
      headlineSmall: display.headlineSmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.4),
      titleLarge: display.titleLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.3),
      titleMedium: body.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: body.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: body.bodyLarge,
      bodyMedium: body.bodyMedium,
      bodySmall: body.bodySmall,
      labelLarge: body.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      labelMedium: body.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      labelSmall: body.labelSmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.3),
    );
  }
}

/// Shared decorative helpers used across screens (badges, status chips,
/// section labels) so the "premium" details stay consistent everywhere
/// rather than being re-invented per screen.
class AppDeco {
  AppDeco._();

  /// The small pill badge style used for "live status" indicators
  /// (e.g. "Volumetric 3D Tracking Enabled", "Within geofence").
  static BoxDecoration statusPill(Color color, {double opacity = 0.1}) {
    return BoxDecoration(
      color: color.withValues(alpha: opacity),
      borderRadius: AppRadius.smR,
      border: Border.all(color: color.withValues(alpha: opacity * 2), width: 1),
    );
  }

  /// Soft glow used behind key icons/marks (role selection, check-in).
  static List<BoxShadow> glow(Color color, {double opacity = 0.18, double blur = 32, double spread = 6}) {
    return [
      BoxShadow(color: color.withValues(alpha: opacity), blurRadius: blur, spreadRadius: spread),
    ];
  }
}
