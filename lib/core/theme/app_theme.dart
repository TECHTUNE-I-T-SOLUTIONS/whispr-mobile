import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Design tokens for Whispr mobile.
///
/// The previous theme declared two nearly identical `TextTheme`s by hand, so
/// every screen re-declared its own font sizes on top. This keeps one token
/// set, one type ramp, and lets widgets read from `Theme.of(context)`.
class AppTheme {
  AppTheme._();

  // ---------------------------------------------------------------------------
  // Brand
  // ---------------------------------------------------------------------------
  static const Color primaryColor = Color(0xFF911A1B);
  static const Color primaryDark = Color(0xFF6B1415);
  static const Color primaryLight = Color(0xFFB82526);
  static const Color primaryTint = Color(0xFFF5E8E8);

  // ---------------------------------------------------------------------------
  // Light surfaces
  // ---------------------------------------------------------------------------
  static const Color lightBackground = Color(0xFFFCFBFA);
  static const Color lightSurface = Colors.white;
  static const Color lightSurfaceAlt = Color(0xFFF6F3F1);
  static const Color lightTextPrimary = Color(0xFF151212);
  static const Color lightTextSecondary = Color(0xFF6B6360);

  // ---------------------------------------------------------------------------
  // Dark surfaces — near-black with a warm cast, not pure #000, so elevated
  // cards are visible and OLED screens do not smear on scroll.
  // ---------------------------------------------------------------------------
  static const Color darkBackground = Color(0xFF0B0A0A);
  static const Color darkSurface = Color(0xFF141212);
  static const Color darkSurfaceAlt = Color(0xFF1C1919);
  static const Color darkTextPrimary = Color(0xFFF5F1EF);
  static const Color darkTextSecondary = Color(0xFF9E9691);

  // ---------------------------------------------------------------------------
  // Semantic
  // ---------------------------------------------------------------------------
  static const Color errorColor = Color(0xFFD33B3B);
  static const Color successColor = Color(0xFF3E7A44);
  static const Color warningColor = Color(0xFFB77B22);

  // ---------------------------------------------------------------------------
  // Spacing scale
  // ---------------------------------------------------------------------------
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;

  // ---------------------------------------------------------------------------
  // Shape
  // ---------------------------------------------------------------------------
  static const double borderRadiusS = 10.0;
  static const double borderRadiusM = 14.0;
  static const double borderRadiusL = 20.0;
  static const double borderRadiusXL = 26.0;

  // ---------------------------------------------------------------------------
  // Motion — short and consistent. Nothing loops.
  // ---------------------------------------------------------------------------
  static const Duration shortAnimation = Duration(milliseconds: 160);
  static const Duration mediumAnimation = Duration(milliseconds: 240);
  static const Duration longAnimation = Duration(milliseconds: 380);

  /// Reading type. Serif for anything the user actually reads at length.
  static const String serifFamily = 'serif';

  static TextTheme _textTheme(Color primary, Color secondary) {
    return TextTheme(
      displaySmall: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, height: 1.16, letterSpacing: -0.5, color: primary),
      headlineMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: -0.3, color: primary),
      headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.24, letterSpacing: -0.2, color: primary),
      titleLarge: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, height: 1.3, color: primary),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.35, color: primary),
      titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.4, color: primary),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.55, color: primary),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.55, color: primary),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 1.45, color: secondary),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: 0.1, color: primary),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.2, color: secondary),
      labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, height: 1.2, letterSpacing: 0.3, color: secondary),
    );
  }

  static final ThemeData lightTheme = _build(
    brightness: Brightness.light,
    background: lightBackground,
    surface: lightSurface,
    surfaceAlt: lightSurfaceAlt,
    textPrimary: lightTextPrimary,
    textSecondary: lightTextSecondary,
    overlayStyle: SystemUiOverlayStyle.dark,
    fillColor: lightSurfaceAlt,
    outline: Colors.black.withValues(alpha: 0.08),
  );

  static final ThemeData darkTheme = _build(
    brightness: Brightness.dark,
    background: darkBackground,
    surface: darkSurface,
    surfaceAlt: darkSurfaceAlt,
    textPrimary: darkTextPrimary,
    textSecondary: darkTextSecondary,
    overlayStyle: SystemUiOverlayStyle.light,
    fillColor: darkSurfaceAlt,
    outline: Colors.white.withValues(alpha: 0.08),
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color surfaceAlt,
    required Color textPrimary,
    required Color textSecondary,
    required SystemUiOverlayStyle overlayStyle,
    required Color fillColor,
    required Color outline,
  }) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: isDark ? const Color(0xFFCF5A5B) : primaryColor,
      onPrimary: Colors.white,
      primaryContainer: isDark ? const Color(0xFF3A1617) : primaryTint,
      onPrimaryContainer: isDark ? const Color(0xFFF6D9DA) : primaryDark,
      secondary: isDark ? const Color(0xFFCF5A5B) : primaryColor,
      onSecondary: Colors.white,
      secondaryContainer: isDark ? const Color(0xFF3A1617) : primaryTint,
      onSecondaryContainer: isDark ? const Color(0xFFF6D9DA) : primaryDark,
      surface: surface,
      onSurface: textPrimary,
      surfaceContainerHighest: surfaceAlt,
      onSurfaceVariant: textSecondary,
      error: errorColor,
      onError: Colors.white,
      outline: outline,
      outlineVariant: outline,
    );

    final textTheme = _textTheme(textPrimary, textSecondary);
    final radiusM = BorderRadius.circular(borderRadiusM);
    final radiusL = BorderRadius.circular(borderRadiusL);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: scheme.primary,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      cardColor: surface,
      dividerColor: outline,
      colorScheme: scheme,
      textTheme: textTheme,
      fontFamilyFallback: const ['SF Pro Text', 'Roboto', 'Segoe UI', 'Helvetica Neue'],
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        systemOverlayStyle: overlayStyle.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: background,
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
        iconTheme: IconThemeData(color: textPrimary, size: 22),
        actionsIconTheme: IconThemeData(color: textPrimary, size: 22),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: radiusL, side: BorderSide(color: outline)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: spacingL),
          shape: RoundedRectangleBorder(borderRadius: radiusM),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: spacingL),
          shape: RoundedRectangleBorder(borderRadius: radiusM),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: outline),
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: spacingL),
          shape: RoundedRectangleBorder(borderRadius: radiusM),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fillColor,
        hintStyle: TextStyle(color: textSecondary, fontSize: 14, fontWeight: FontWeight.w400),
        labelStyle: TextStyle(color: textSecondary, fontSize: 14),
        floatingLabelStyle: TextStyle(color: scheme.primary, fontSize: 13, fontWeight: FontWeight.w600),
        border: OutlineInputBorder(borderRadius: radiusM, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: radiusM, borderSide: BorderSide(color: outline)),
        focusedBorder: OutlineInputBorder(borderRadius: radiusM, borderSide: BorderSide(color: scheme.primary, width: 1.6)),
        errorBorder: OutlineInputBorder(borderRadius: radiusM, borderSide: const BorderSide(color: errorColor)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: radiusM, borderSide: const BorderSide(color: errorColor, width: 1.6)),
        contentPadding: const EdgeInsets.symmetric(horizontal: spacingM, vertical: 14),
        isDense: true,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceAlt,
        selectedColor: scheme.primary.withValues(alpha: 0.14),
        side: BorderSide(color: outline),
        labelStyle: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textPrimary),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
      ),
      dividerTheme: DividerThemeData(color: outline, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF2A2525) : const Color(0xFF241F1E),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: radiusM),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(borderRadiusXL)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radiusL),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: surfaceAlt,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: textSecondary,
        textColor: textPrimary,
        contentPadding: const EdgeInsets.symmetric(horizontal: spacingM, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: radiusM),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.12),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? scheme.primary : textSecondary,
          ),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: textSecondary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
      ),
    );
  }
}
