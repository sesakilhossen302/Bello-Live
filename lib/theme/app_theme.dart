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
      backgroundColor: Colors.transparent, // transparent app bar
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
        systemNavigationBarColor: Colors.black,
        // or AppColors.bg
        systemNavigationBarIconBrightness: Brightness.light, // white icons
      ),
    ),
  );
}

class AppColors {
  static Color primary = pinkDark;
  static const Color primaryLight = Color(0xFFDAE3F1);
  static const Color bg = Color(0xFFFFFFFF);
  static const Color text = Color(0xFF1E1E1E);
  static const Color textLight = Color(0xFF616161);

  // Primary colors
  static const Color black = Colors.black;
  static const Color white = Colors.white;

  static Color pinkLight = Colors.pink.shade300;
  static Color pinkDark = Colors.pink.shade500;
  static Color pink400 = Colors.pink.shade400;
  static Color pink = Colors.pink;
  static Color pink600 = Colors.pink.shade600;

  // Background gradient
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF000000), Color(0xFF1a0a0a), Color(0xFF2d1b2b), Color(0xFF4a2c4a), Color(0xFFff6b9d)],
    stops: [0.0, 0.3, 0.6, 0.8, 1.0],
  );

  // Logo gradient
  static LinearGradient logoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [pinkLight, pinkDark],
  );

  // Tab indicator gradient
  static LinearGradient tabIndicatorGradient = LinearGradient(colors: [Colors.pink.shade400, Colors.pink.shade600]);

  // Button gradient
  static LinearGradient buttonGradient = LinearGradient(colors: [Colors.pink.shade400, Colors.pink.shade600]);

  // Shadows
  static List<BoxShadow> logoShadow = [
    BoxShadow(color: Colors.pink.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10)),
  ];

  static List<BoxShadow> buttonShadow = [
    BoxShadow(color: Colors.pink.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 6)),
  ];

  // Input decoration colors
  static Color inputBorderColor = Colors.pink.withValues(alpha: 0.3);
  static Color inputBackground = Colors.black.withValues(alpha: 0.2);

  // Divider gradients
  static Gradient dividerLeft = LinearGradient(colors: [Colors.transparent, Colors.white.withValues(alpha: 0.3)]);
  static Gradient dividerRight = LinearGradient(colors: [Colors.white.withValues(alpha: 0.3), Colors.transparent]);

  // Shader for texts
  static Shader textGradientShader(Rect bounds) {
    return LinearGradient(colors: [pinkLight, pinkDark]).createShader(bounds);
  }
}
