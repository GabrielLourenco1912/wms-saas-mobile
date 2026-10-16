import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../branding/brand_tokens.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get light {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: BrandColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: BrandColors.primary,
          onPrimary: BrandColors.onPrimary,
          primaryContainer: BrandColors.soft,
          onPrimaryContainer: BrandColors.primaryHover,
          secondary: BrandColors.accent,
          onSecondary: BrandColors.onAccent,
          secondaryContainer: BrandColors.soft,
          onSecondaryContainer: BrandColors.primaryHover,
          tertiary: BrandColors.info,
          onTertiary: Colors.white,
          tertiaryContainer: BrandColors.infoBackground,
          onTertiaryContainer: BrandColors.info,
          surface: BrandColors.surface,
          onSurface: BrandColors.text,
          onSurfaceVariant: BrandColors.muted,
          surfaceContainerLowest: BrandColors.surface,
          surfaceContainerLow: BrandColors.background,
          surfaceContainer: BrandColors.surfaceMuted,
          surfaceContainerHigh: BrandColors.surfaceMuted,
          surfaceContainerHighest: BrandColors.border,
          outline: BrandColors.control,
          outlineVariant: BrandColors.border,
          inverseSurface: BrandColors.ink,
          onInverseSurface: BrandColors.inverseText,
          inversePrimary: BrandColors.accent,
          error: BrandColors.danger,
          onError: Colors.white,
          errorContainer: BrandColors.dangerBackground,
          onErrorContainer: BrandColors.danger,
        );
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppBrand.controlRadius),
    );
    const buttonText = TextStyle(
      fontFamily: AppBrand.sansFont,
      fontSize: 16,
      fontWeight: FontWeight.w700,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: AppBrand.sansFont,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: BrandColors.background,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontSize: 36,
          height: 1.1,
          fontWeight: FontWeight.w700,
        ),
        headlineLarge: TextStyle(
          fontSize: 28,
          height: 1.2,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          height: 1.2,
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: TextStyle(
          fontSize: 26,
          height: 1.2,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          height: 1.3,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          height: 1.4,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: TextStyle(
          fontSize: 16,
          height: 1.4,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(fontSize: 16, height: 1.5),
        bodyMedium: TextStyle(fontSize: 16, height: 1.5),
        bodySmall: TextStyle(
          fontSize: 14,
          height: 1.45,
          color: BrandColors.muted,
        ),
        labelLarge: buttonText,
        labelMedium: TextStyle(
          fontSize: 14,
          height: 1.4,
          fontWeight: FontWeight.w600,
        ),
        labelSmall: TextStyle(
          fontSize: 12,
          height: 1.4,
          fontWeight: FontWeight.w600,
        ),
      ).apply(bodyColor: BrandColors.text, displayColor: BrandColors.text),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: BrandColors.background,
        foregroundColor: BrandColors.text,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          fontFamily: AppBrand.sansFont,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: BrandColors.text,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: BrandColors.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBrand.cardRadius),
          side: const BorderSide(color: BrandColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BrandColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBrand.controlRadius),
          borderSide: const BorderSide(color: BrandColors.control),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBrand.controlRadius),
          borderSide: const BorderSide(color: BrandColors.control),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBrand.controlRadius),
          borderSide: const BorderSide(color: BrandColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBrand.controlRadius),
          borderSide: const BorderSide(color: BrandColors.danger),
        ),
        helperMaxLines: 4,
        errorMaxLines: 4,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: controlShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: controlShape,
          side: const BorderSide(color: BrandColors.control),
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          shape: controlShape,
          textStyle: buttonText,
        ),
      ),
      iconButtonTheme: const IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(Size.square(48)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: BrandColors.border,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: BrandColors.ink,
        contentTextStyle: const TextStyle(
          fontFamily: AppBrand.sansFont,
          fontSize: 14,
          color: BrandColors.inverseText,
        ),
        behavior: SnackBarBehavior.floating,
        shape: controlShape,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: BrandColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: BrandColors.accent,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: AppBrand.sansFont,
            fontSize: 13,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? BrandColors.text
                : BrandColors.muted,
          ),
        ),
      ),
    );
  }
}
