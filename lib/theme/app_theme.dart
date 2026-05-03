import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData themeData() => ThemeData(
    useMaterial3: true,
    splashFactory: NoSplash.splashFactory,
    applyElevationOverlayColor: false,

    // Apply Google Fonts Inter everywhere
    textTheme: GoogleFonts.interTextTheme().apply(bodyColor: AppColors.text, displayColor: AppColors.text),

    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.barColor, // Updated bar color
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        // Status bar
        statusBarColor: Colors.transparent,
        // fully transparent
        statusBarIconBrightness: Brightness.light,
        // white icons (Android)
        statusBarBrightness: Brightness.dark,
        // white icons (iOS)

        // Navigation bar
        systemNavigationBarColor: AppColors.bg,
        // or AppColors.bg
        systemNavigationBarIconBrightness: Brightness.light, // white icons
      ),
    ),
  );
}

class AppColors {
  static const Color primary = Color(0xFFFFC0CB); // Light Pink from user image
  static const Color primaryLight = Color(0xFFFFB6C1);
  static const Color bg = Color(0xFFD69AA4); // Solid dusty rose from user image
  static const Color barColor = Color(0xFF8B6C77); // Darker dusty rose for bars
  static const Color text = Color(0xFFFFFFFF);
  static const Color textLight = Color(0xFFE0E0E0);

  // Primary colors
  static const Color black = Colors.black;
  static const Color white = Colors.white;

  static const Color pinkLight = Color(0xFFFFD1DC);
  static const Color pinkDark = Color(0xFFFFB6C1);
  static const Color pink400 = Color(0xFFFFC0CB);
  static const Color pink = Color(0xFFFFC0CB);
  static const Color pink600 = Color(0xFFF8BBD0);

  // Background gradient
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFD69AA4), Color(0xFFD69AA4)],
    stops: [0.0, 1.0],
  );

  // Logo gradient
  static LinearGradient logoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [pinkLight, pinkDark],
  );

  // Tab indicator gradient
  static LinearGradient tabIndicatorGradient = LinearGradient(colors: [pink400, pink600]);

  // Button gradient
  static LinearGradient buttonGradient = LinearGradient(colors: [pink400, pink600]);

  // Shadows
  static List<BoxShadow> logoShadow = [
    BoxShadow(color: pink.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10)),
  ];

  static List<BoxShadow> buttonShadow = [
    BoxShadow(color: pink.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 6)),
  ];

  // Input decoration colors
  static Color inputBorderColor = pink.withValues(alpha: 0.3);
  static Color inputBackground = Colors.black.withValues(alpha: 0.2);

  // Divider gradients
  static Gradient dividerLeft = LinearGradient(colors: [Colors.transparent, Colors.white.withValues(alpha: 0.3)]);
  static Gradient dividerRight = LinearGradient(colors: [Colors.white.withValues(alpha: 0.3), Colors.transparent]);

  // Shader for texts
  static Shader textGradientShader(Rect bounds) {
    return LinearGradient(colors: [pinkLight, pinkDark]).createShader(bounds);
  }
}
