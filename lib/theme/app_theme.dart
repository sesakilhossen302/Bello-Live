import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Brand Colors
  static const primaryColor = Color(0xFF5A189A);
  static const primary = Color(0xFF5A189A);
  static const secondary = Color(0xFF9D4EDD);
  static const accent = Color(0xFF1E88FF);

  // Background
  static const backgroundColor = Color(0xFF0D1B2A);
  static const background = Color(0xFF0D1B2A);
  
  static const pinkGlow = Color(0xFFFF1E7A);
  static const purpleGlow = Color(0xFF7C245A);
  static const redGlow = Color(0xFFFF1D2E);
  static const greenGlow = Color(0xFF123F3D);
  static const darkBlueGlow = Color(0xFF0A1B28);
  static const surface = Color(0xFF161622);
  static const card = Color(0xFF1F1F2E);

  // Text
  static const white = Color(0xFFFFFFFF);
  static const grey = Color(0xFFB3BCD4);
  static const hint = Color(0xFF7B84A3);

  // Status
  static const success = Color(0xFF00E676);
  static const warning = Color(0xFFFFB300);
  static const error = Color(0xFFFF5252);

  // Live
  static const live = Color(0xFFFF1744);
  
  // Wallet / Recharge
  static const goldAccent = Color(0xFFFFB300);

  // ==========================================
  // LEGACY ALIASES (Prevents compilation errors)
  // ==========================================
  static const Color primaryLight = secondary; 
  static const Color bg = background; 
  static const Color barColor = surface; 
  static const Color text = white;
  static const Color textLight = grey;
  
  static const Color black = Colors.black;
  // static const Color white = Colors.white; // Already defined above

  static const Color pinkLight = primary;
  static const Color pinkDark = secondary;
  static const Color pink400 = primary;
  static const Color pink = primary;
  static const Color pink600 = accent;

  static const LinearGradient backgroundGradient = AppGradients.backgroundGradient;
  
  static LinearGradient logoGradient = AppGradients.primaryGradient;
  static LinearGradient tabIndicatorGradient = AppGradients.primaryGradient;
  static LinearGradient buttonGradient = AppGradients.primaryGradient;

  static List<BoxShadow> logoShadow = [
    BoxShadow(
      color: primary.withValues(alpha: 0.3),
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> buttonShadow = [
    BoxShadow(
      color: primary.withValues(alpha: 0.4),
      blurRadius: 12,
      offset: const Offset(0, 6),
    ),
  ];

  static Color inputBorderColor = primary.withValues(alpha: 0.3);
  static Color inputBackground = Colors.black.withValues(alpha: 0.2);

  static Gradient dividerLeft = LinearGradient(
    colors: [Colors.transparent, Colors.white.withValues(alpha: 0.3)],
  );
  static Gradient dividerRight = LinearGradient(
    colors: [Colors.white.withValues(alpha: 0.3), Colors.transparent],
  );

  static Shader textGradientShader(Rect bounds) {
    return AppGradients.primaryGradient.createShader(bounds);
  }
}

class AppGradients {
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [
      Color(0xFF5A189A), // Primary Pink
      Color(0xFF9D4EDD), // Purple
      Color(0xFF1E88FF), // Blue
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient rechargeGradient = LinearGradient(
    colors: [
      Color(0xFF5A189A), // Primary Pink
      Color(0xFF9D4EDD), // Purple
    ],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.background, AppColors.surface],
  );
}

class AppTheme {
  static ThemeData themeData() => ThemeData(
    useMaterial3: true,
    splashFactory: NoSplash.splashFactory,
    applyElevationOverlayColor: false,

    textTheme: GoogleFonts.interTextTheme().apply(
      bodyColor: AppColors.white,
      displayColor: AppColors.white,
    ),

    scaffoldBackgroundColor: Colors.transparent,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
      surface: AppColors.surface,
      error: AppColors.error,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: AppColors.white),
      titleTextStyle: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: AppColors.white,
      ),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    ),
    
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.hint,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
  );

  static BoxDecoration cardDecoration() {
    return BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: const Color(0xFF2E2E40),
      ),
    );
  }

  static BoxDecoration primaryButtonDecoration() {
    return BoxDecoration(
      gradient: AppGradients.primaryGradient,
      borderRadius: BorderRadius.circular(16),
    );
  }

  static BoxDecoration secondaryButtonDecoration() {
    return BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: const Color(0xFF2E2E40),
      ),
    );
  }
}

class GlobalAppBackground extends StatelessWidget {
  const GlobalAppBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppGradients.backgroundGradient,
      ),
    );
  }
}
