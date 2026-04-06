import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primary = Color(0xFF003F98);
  static const Color primaryContainer = Color(0xFF1A56BE);
  static const Color onPrimary = Colors.white;
  static const Color onPrimaryContainer = Color(0xFFC5D4FF);

  static const Color secondary = Color(0xFF1B6D24);
  static const Color secondaryContainer = Color(0xFFA0F399);
  static const Color onSecondary = Colors.white;
  static const Color onSecondaryContainer = Color(0xFF217128);

  static const Color tertiary = Color(0xFF004D50);
  static const Color tertiaryContainer = Color(0xFF0F666A);
  static const Color onTertiary = Colors.white;

  static const Color background = Color(0xFFF8F9FA);
  static const Color onBackground = Color(0xFF191C1D);

  static const Color surface = Color(0xFFF8F9FA);
  static const Color onSurface = Color(0xFF191C1D);
  static const Color surfaceVariant = Color(0xFFE1E3E4);
  static const Color onSurfaceVariant = Color(0xFF434653);

  static const Color surfaceContainerLow = Color(0xFFF3F4F5);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerHigh = Color(0xFFE7E8E9);
  static const Color surfaceContainerHighest = Color(0xFFE1E3E4);
  static const Color outline = Color(0xFF737784);
  static const Color outlineVariant = Color(0xFFC3C6D5);

  // Dark Mode Tokens (Archivist Kinetic)
  static const Color darkBackground = Color(0xFF131313);
  static const Color darkOnBackground = Color(0xFFE5E2E1);
  static const Color darkPrimary = Color(0xFFB8C3FF);
  static const Color darkPrimaryContainer = Color(0xFF2E5BFF);
  static const Color darkOnPrimary = Color(0xFF002388);
  static const Color darkOnPrimaryContainer = Color(0xFFEFEFFF);
  static const Color darkSecondary = Color(0xFFFFFFFF);
  static const Color darkSecondaryContainer = Color(0xFFC6F300);
  static const Color darkOnSecondary = Color(0xFF293500);

  static const Color darkSurface = Color(0xFF131313);
  static const Color darkOnSurface = Color(0xFFE5E2E1);
  static const Color darkSurfaceContainerLow = Color(0xFF1B1B1C);
  static const Color darkSurfaceContainer = Color(0xFF202020);
  static const Color darkSurfaceContainerHigh = Color(0xFF2A2A2A);
  static const Color darkSurfaceContainerHighest = Color(0xFF353535);
  static const Color darkSurfaceContainerLowest = Color(0xFF0E0E0E);
  static const Color darkOutline = Color(0xFF8E90A2);
  static const Color darkOutlineVariant = Color(0xFF434656);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        onPrimary: onPrimary,
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
        secondary: secondary,
        onSecondary: onSecondary,
        secondaryContainer: secondaryContainer,
        onSecondaryContainer: onSecondaryContainer,
        tertiary: tertiary,
        onTertiary: onTertiary,
        tertiaryContainer: tertiaryContainer,
        surface: surface,
        onSurface: onSurface,
        surfaceContainerLow: surfaceContainerLow,
        surfaceContainerLowest: surfaceContainerLowest,
        surfaceContainerHigh: surfaceContainerHigh,
        surfaceContainerHighest: surfaceContainerHighest,
        outline: outline,
        outlineVariant: outlineVariant,
      ),
      scaffoldBackgroundColor: background,
      textTheme: _textTheme(onBackground, onSurfaceVariant),
      cardTheme: _cardTheme(surfaceContainerLowest),
      appBarTheme: _appBarTheme(onSurface),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: darkPrimary,
        brightness: Brightness.dark,
        primary: darkPrimary,
        onPrimary: darkOnPrimary,
        primaryContainer: darkPrimaryContainer,
        onPrimaryContainer: darkOnPrimaryContainer,
        secondary: darkSecondary,
        onSecondary: darkOnSecondary,
        secondaryContainer: darkSecondaryContainer,
        surface: darkSurface,
        onSurface: darkOnSurface,
        surfaceContainerLow: darkSurfaceContainerLow,
        surfaceContainerLowest: darkSurfaceContainerLowest,
        surfaceContainerHigh: darkSurfaceContainerHigh,
        surfaceContainerHighest: darkSurfaceContainerHighest,
        outline: darkOutline,
        outlineVariant: darkOutlineVariant,
      ),
      scaffoldBackgroundColor: darkBackground,
      textTheme: _textTheme(
        darkOnBackground,
        const Color(0xFFC4C5D9),
        isDark: true,
      ),
      cardTheme: _cardTheme(darkSurfaceContainer),
      appBarTheme: _appBarTheme(darkOnSurface),
    );
  }

  static TextTheme _textTheme(
    Color main,
    Color variant, {
    bool isDark = false,
  }) {
    return TextTheme(
      displayLarge: GoogleFonts.manrope(
        fontSize: 56,
        fontWeight: FontWeight.bold,
        color: main,
        letterSpacing: -1,
      ),
      headlineSmall: GoogleFonts.manrope(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: main,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: main,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: main,
      ),
      labelSmall: isDark
          ? GoogleFonts.spaceGrotesk(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: variant,
            )
          : GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: variant,
            ),
    );
  }

  static CardThemeData _cardTheme(Color background) {
    return CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: background,
    );
  }

  static AppBarTheme _appBarTheme(Color onSurface) {
    return AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: onSurface),
      titleTextStyle: GoogleFonts.manrope(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: onSurface,
      ),
    );
  }

  static List<BoxShadow> ambientShadow({double opacity = 0.04, double blur = 16}) {
    return [
      BoxShadow(
        color: onSurface.withValues(alpha: opacity),
        blurRadius: blur,
        offset: const Offset(0, 4),
      ),
    ];
  }

  static BoxDecoration signatureGradientDecoration({double radius = 12}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: const LinearGradient(
        colors: [primary, primaryContainer],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      boxShadow: [
        BoxShadow(
          color: primary.withValues(alpha: 0.3),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  static Border ghostBorder({double opacity = 0.15}) {
    return Border.all(
      color: outlineVariant.withValues(alpha: opacity),
      width: 1,
    );
  }
}
