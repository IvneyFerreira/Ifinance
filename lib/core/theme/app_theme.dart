import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Tema do NeyFlow. Dark mode tratado como experiência de primeira classe
/// (não apenas inversão de cores), com contraste e elevação próprios.
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.emerald,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.emeraldDark,
      surface: AppColors.lightCard,
      error: AppColors.negative,
    );
    return _build(base, Brightness.light);
  }

  static ThemeData dark() {
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.emerald,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.emeraldSoft,
      surface: AppColors.darkCard,
      error: AppColors.negativeSoft,
    );
    return _build(base, Brightness.dark);
  }

  static ThemeData _build(ColorScheme scheme, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final textTheme = GoogleFonts.interTextTheme(
      isDark
          ? ThemeData.dark().textTheme
          : ThemeData.light().textTheme,
    ).apply(bodyColor: textColor, displayColor: textColor);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          isDark ? AppColors.darkBg : AppColors.lightBg,
      textTheme: textTheme,
      fontFamily: GoogleFonts.inter().fontFamily,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor:
            isDark ? AppColors.darkBg : AppColors.lightBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
        iconTheme: IconThemeData(color: textColor),
      ),
      cardTheme: CardThemeData(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? AppColors.surfaceDark
            : AppColors.gray100,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.emerald, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.negative),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: secondary),
        labelStyle: textTheme.bodyMedium?.copyWith(color: secondary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.emerald,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textColor,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.emerald),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.gray100,
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        labelStyle: textTheme.bodySmall!,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.emerald.withValues(alpha: 0.16),
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.emerald : secondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.emerald : secondary,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.surfaceDarkElevated : AppColors.graphite,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: AppColors.emerald),
    );
  }
}
