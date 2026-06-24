import 'package:flutter/material.dart';

import 'alfred_colors.dart';

abstract final class AlfredTheme {
  static ThemeData get light {
    const scheme = ColorScheme.light(
      primary: AlfredColors.charcoal,
      onPrimary: AlfredColors.textOnDark,
      surface: AlfredColors.panel,
      onSurface: AlfredColors.textPrimary,
      outline: AlfredColors.border,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AlfredColors.surface,
      fontFamily: 'Inter',
      appBarTheme: const AppBarTheme(
        backgroundColor: AlfredColors.charcoal,
        foregroundColor: AlfredColors.textOnDark,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AlfredColors.panel,
        hintStyle: const TextStyle(color: AlfredColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
      dividerTheme: const DividerThemeData(color: AlfredColors.border, space: 1),
    );
  }
}
