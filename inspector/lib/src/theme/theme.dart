import 'package:flutter/material.dart';

import 'tokens.dart';

abstract final class InspectorTheme {
  static final ThemeData darkTheme = _build();

  static ThemeData _build() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: Tokens.surface,
      colorScheme: const ColorScheme.dark(
        primary: Tokens.system,
        secondary: Tokens.component,
        surface: Tokens.card,
        error: Tokens.logError,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Tokens.card,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Tokens.card,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Tokens.elevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Tokens.spaceLg,
          vertical: Tokens.spaceMd,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Tokens.elevated,
        selectedColor: Tokens.system.withValues(alpha: 0.3),
        labelStyle: const TextStyle(color: Tokens.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: const DividerThemeData(
        color: Tokens.elevated,
        thickness: 1,
      ),
    );
  }
}
