import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand
  static const primaryDark = Color(0xFF00695C);
  static const primaryGreen = Color(0xFF16A34A);
  static const brandGreen = Color(0xFF076B3B);

  // Surfaces
  static const pageBackground = Color(0xFFF7F8FE);
  static const card = Colors.white;
  static const mint = Color(0xFFD5EFE5);
  static const mintSoft = Color(0xFFE8F6F0);
  static const chipBlue = Color(0xFFE6EBFA);
  static const chipBlueSoft = Color(0xFFEFF2FC);
  static const aqua = Color(0xFF86F0D6);

  // Text
  static const textPrimary = Color(0xFF14201C);
  static const textMuted = Color(0xFF5E6B66);
  static const textFaint = Color(0xFF8A9792);

  // Status
  static const danger = Color(0xFFC62828);
  static const dangerSoft = Color(0xFFFCE4E4);
  static const success = Color(0xFF1B7F4B);
  static const successSoft = Color(0xFFD7F5E3);

  // Back-compat aliases used across screens
  static const lightGreen = mint;
  static const infoSoft = chipBlue;
  static const info = Color(0xFF3B5BB5);
  static const warning = Color(0xFFB26A00);
  static const warningSoft = Color(0xFFFFF0D6);
}

/// Bundled fonts (see assets/fonts). No runtime downloads.
class AppText {
  AppText._();

  static TextStyle poppins({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      TextStyle(
        fontFamily: 'Poppins',
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  /// Clinical-label style used on the prescribe sheet (system monospace).
  static TextStyle mono({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
  }) =>
      TextStyle(
        fontFamily: 'monospace',
        fontFamilyFallback: const ['Courier', 'Courier New'],
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
      );

  static TextStyle inter({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      TextStyle(
        fontFamily: 'Inter',
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontVariations: [
          FontVariation('wght', (fontWeight ?? FontWeight.w400).value.toDouble()),
        ],
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.primaryDark,
      primary: AppColors.primaryDark,
      secondary: AppColors.primaryGreen,
      surface: Colors.white,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: base,
      scaffoldBackgroundColor: AppColors.pageBackground,
      fontFamily: 'Inter',
      splashFactory: InkRipple.splashFactory,
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: AppText.inter(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          textStyle: AppText.inter(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: AppText.inter(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        elevation: 8,
        shadowColor: Colors.black26,
        height: 68,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 26,
            color: states.contains(WidgetState.selected)
                ? AppColors.primaryDark
                : AppColors.textPrimary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => AppText.inter(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? AppColors.primaryDark
                : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
