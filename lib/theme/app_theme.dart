import 'package:flutter/material.dart';

/// Bảng màu dùng chung cho Mobile và Web Customer.
class AppColors {
  AppColors._();

  static const primary = Color(0xFF13B5A5);
  static const primaryDark = Color(0xFF0B8B7F);
  static const primarySoft = Color(0xFFE3F6F3);
  static const ink = Color(0xFF15302F);
  static const inkSoft = Color(0xFF55706D);
  static const muted = Color(0xFF8FA3A0);
  static const line = Color(0xFFE3EBE9);
  static const bg = Color(0xFFF4F8F7);
  static const surface = Color(0xFFFFFFFF);
  static const accent = Color(0xFFFF8A3D);
  static const accentSoft = Color(0xFFFFF1E6);
  static const success = Color(0xFF1E9E5A);
  static const successSoft = Color(0xFFE6F6EC);
  static const warning = Color(0xFFD9910B);
  static const warningSoft = Color(0xFFFFF6DE);
  static const danger = Color(0xFFD9473F);
  static const dangerSoft = Color(0xFFFDECEA);
  static const info = Color(0xFF2F7BE5);
  static const infoSoft = Color(0xFFE8F1FD);

  /// Nền nhạt tương ứng 1 màu trạng thái.
  static Color soft(Color color) => color.withValues(alpha: 0.12);
}

class AppRadius {
  AppRadius._();

  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
}

/// Phông chữ dùng chung với Web Customer (khai báo trong pubspec.yaml).
const kFontFamily = 'BeVietnamPro';

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    secondary: AppColors.accent,
    surface: AppColors.surface,
    error: AppColors.danger,
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: kFontFamily,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    dividerColor: AppColors.line,
    // Chuyển trang: mờ dần + trượt nhẹ (giống hiệu ứng trên website)
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeSlidePageTransitionsBuilder(),
        TargetPlatform.iOS: FadeSlidePageTransitionsBuilder(),
        TargetPlatform.windows: FadeSlidePageTransitionsBuilder(),
        TargetPlatform.macOS: FadeSlidePageTransitionsBuilder(),
        TargetPlatform.linux: FadeSlidePageTransitionsBuilder(),
      },
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.primarySoft,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: kFontFamily,
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? AppColors.primaryDark
              : AppColors.inkSoft,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      contentTextStyle: const TextStyle(
        fontFamily: kFontFamily,
        color: Colors.white,
        fontSize: 14,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
    ),
  );
}

/// Hiệu ứng chuyển trang: trang mới mờ dần và trượt lên 4%, trang cũ mờ nhẹ.
class FadeSlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const FadeSlidePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final enter = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final exit = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOut,
    );
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.6).animate(exit),
      child: FadeTransition(
        opacity: enter,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(enter),
          child: child,
        ),
      ),
    );
  }
}

/// Kiểu chữ dùng lại nhiều nơi.
class AppText {
  AppText._();

  static const display = TextStyle(
    fontSize: 26,
    height: 1.2,
    fontWeight: FontWeight.w800,
    color: AppColors.ink,
  );
  static const title = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );
  static const section = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );
  static const body = TextStyle(
    fontSize: 14,
    height: 1.45,
    color: AppColors.ink,
  );
  static const muted = TextStyle(
    fontSize: 13,
    height: 1.4,
    color: AppColors.inkSoft,
  );
  static const small = TextStyle(fontSize: 12, color: AppColors.muted);
  static const label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.inkSoft,
  );
  static const money = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    color: AppColors.primaryDark,
  );
}
