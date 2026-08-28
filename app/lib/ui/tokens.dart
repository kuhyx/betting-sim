import 'package:flutter/material.dart';

/// The shared design tokens, from ~/utils/unified-design-system.
///
/// Values are copied rather than invented: one palette across every app.
abstract final class Tokens {
  /// Dark background. Same value as the shared icon charcoal.
  static const ink = Color(0xFF211D1B);

  /// Dark elevated surface, step 1.
  static const inkRaised1 = Color(0xFF2B2624);

  /// Dark elevated surface, step 2.
  static const inkRaised2 = Color(0xFF38312E);

  /// Border on dark surfaces.
  static const lineDark = Color(0xFF463E3A);

  /// Primary text on dark. Near-white, deliberately not pure.
  static const textOnDark = Color(0xFFECEAE9);

  /// Secondary and caption text on dark.
  static const mutedOnDark = Color(0xFFAAA09A);

  /// The one accent.
  static const accent = Color(0xFFB8862E);

  /// Positive state.
  static const success = Color(0xFF8A9A3C);

  /// Caution state.
  static const warning = Color(0xFFE0A63C);

  /// Negative state.
  static const danger = Color(0xFFE2585F);

  /// Text drawn ON TOP of a filled accent/success/warning/danger surface.
  ///
  /// Never [textOnDark]: all four fills sit in the same mid-light band, where
  /// near-white measures 2.2-3.6:1 against WCAG's 4.5:1 floor, while ink
  /// passes on all four at 5.8-9.7:1. A closed rule, not a per-colour call.
  static const Color onFill = ink;

  /// Spacing scale, in logical pixels.
  static const space1 = 4.0;

  /// Spacing scale step 2.
  static const space2 = 8.0;

  /// Spacing scale step 3.
  static const space3 = 12.0;

  /// Spacing scale step 4.
  static const space4 = 16.0;

  /// Spacing scale step 5.
  static const space5 = 24.0;

  /// Spacing scale step 6.
  static const space6 = 32.0;

  /// Corner radius for cards and surfaces.
  static const radius = 8.0;

  /// Corner radius for small chips and badges.
  static const radiusSmall = 4.0;
}

/// The app's theme, built from [Tokens].
ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    surface: Tokens.ink,
    onSurface: Tokens.textOnDark,
    primary: Tokens.accent,
    onPrimary: Tokens.onFill,
    secondary: Tokens.accent,
    onSecondary: Tokens.onFill,
    error: Tokens.danger,
    onError: Tokens.onFill,
    outline: Tokens.lineDark,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Tokens.ink,
    fontFamily: 'monospace',
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        color: Tokens.textOnDark,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        color: Tokens.textOnDark,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      bodyMedium: TextStyle(color: Tokens.textOnDark, fontSize: 14),
      bodySmall: TextStyle(color: Tokens.mutedOnDark, fontSize: 12),
    ),
    cardTheme: const CardThemeData(
      color: Tokens.inkRaised1,
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    dividerTheme: const DividerThemeData(color: Tokens.lineDark, thickness: 1),
  );
}
