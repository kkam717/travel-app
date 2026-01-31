import 'package:flutter/material.dart';

/// Design system for Travel App – warm, inviting, travel-inspired aesthetic
class AppTheme {
  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 16;
  static const double spacingLg = 24;
  static const double spacingXl = 32;
  static const double spacingXxl = 48;

  // Warm travel palette – teal primary, coral accent, soft neutrals
  static const Color _primary = Color(0xFF0D9488); // Teal
  static const Color _primaryVariant = Color(0xFF0F766E);
  static const Color _secondary = Color(0xFFE07856); // Warm coral
  static const Color _surface = Color(0xFFFAFAF9);
  static const Color _surfaceVariant = Color(0xFFF5F5F4);
  static const Color _onSurface = Color(0xFF1C1917);
  static const Color _onSurfaceVariant = Color(0xFF57534E);
  static const Color _outline = Color(0xFFE7E5E4);

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primary,
        primary: _primary,
        secondary: _secondary,
        surface: _surface,
        brightness: Brightness.light,
        error: const Color(0xFFDC2626),
      ),
      scaffoldBackgroundColor: _surface,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: _surface,
        foregroundColor: _onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: _onSurface,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: const BorderSide(color: _outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceVariant,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: const TextStyle(color: _onSurfaceVariant),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentTextStyle: const TextStyle(fontSize: 14),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        backgroundColor: _surface,
      ),
      dividerTheme: const DividerThemeData(color: _outline, thickness: 1),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: _primary,
        unselectedLabelColor: _onSurfaceVariant,
        indicatorColor: _primary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
      ),
      textTheme: _textTheme,
    );
  }

  static TextTheme get _textTheme {
    return TextTheme(
      displayLarge: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -0.5, color: _onSurface),
      displayMedium: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5, color: _onSurface),
      headlineLarge: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.3, color: _onSurface),
      headlineMedium: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.3, color: _onSurface),
      headlineSmall: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _onSurface),
      titleLarge: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _onSurface),
      titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _onSurface),
      titleSmall: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _onSurface),
      bodyLarge: const TextStyle(fontSize: 16, height: 1.5, color: _onSurface),
      bodyMedium: const TextStyle(fontSize: 14, height: 1.5, color: _onSurface),
      bodySmall: const TextStyle(fontSize: 12, height: 1.4, color: _onSurfaceVariant),
      labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _onSurface),
    );
  }
}
