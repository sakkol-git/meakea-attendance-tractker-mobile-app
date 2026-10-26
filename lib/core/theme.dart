import 'package:flutter/material.dart';

import 'package:hrflow_mobile/core/design_tokens.dart';

abstract final class Palette {
  static const teal = Color(0xFF006151),
      ink = Color(0xFF172B29),
      muted = Color(0xFF526560),
      canvas = Color(0xFFF5F7F8),
      line = Color(0xFFD9E2DF),
      tint = Color(0xFFE8F4F0),
      danger = Color(0xFFA12B2B),
      amber = Color(0xFF805400);
}

@immutable
class SemanticColors extends ThemeExtension<SemanticColors> {
  final Color textPrimary, textMuted, surface, card;
  final Color error, onError, errorBackground;
  final Color success, onSuccess, successBackground;
  final Color warning, onWarning, warningBackground;
  final Color info, onInfo, infoBackground;
  final Color disabled, selectedNav, focusRing, divider;
  final Color heroBackground, onHero, onHeroMuted, heroSubtle;

  const SemanticColors({
    required this.textPrimary,
    required this.textMuted,
    required this.surface,
    required this.card,
    required this.error,
    required this.onError,
    required this.errorBackground,
    required this.success,
    required this.onSuccess,
    required this.successBackground,
    required this.warning,
    required this.onWarning,
    required this.warningBackground,
    required this.info,
    required this.onInfo,
    required this.infoBackground,
    required this.disabled,
    required this.selectedNav,
    required this.focusRing,
    required this.divider,
    required this.heroBackground,
    required this.onHero,
    required this.onHeroMuted,
    required this.heroSubtle,
  });

  static const light = SemanticColors(
    textPrimary: Color(0xFF172B29),
    textMuted: Color(0xFF526560),
    surface: Color(0xFFF5F7F8),
    card: Colors.white,
    error: Color(0xFFA12B2B),
    onError: Colors.white,
    errorBackground: Color(0xFFFCEDED),
    success: Color(0xFF17613F),
    onSuccess: Colors.white,
    successBackground: Color(0xFFEAF6EF),
    warning: Color(0xFF805400),
    onWarning: Colors.white,
    warningBackground: Color(0xFFFFF4D6),
    info: Color(0xFF245A91),
    onInfo: Colors.white,
    infoBackground: Color(0xFFEAF2FC),
    disabled: Color(0xFF66766F),
    selectedNav: Color(0xFF006151),
    focusRing: Color(0xFF006151),
    divider: Color(0xFF71857F),
    heroBackground: Color(0xFF006151),
    onHero: Colors.white,
    onHeroMuted: Color(0xFFD1EBE4),
    heroSubtle: Color(0xFF9CE9BF),
  );
  static const dark = SemanticColors(
    textPrimary: Color(0xFFF3F8F5),
    textMuted: Color(0xFFB8CBC3),
    surface: Color(0xFF0E1513),
    card: Color(0xFF1B211F),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF5F1515),
    errorBackground: Color(0xFF3F2524),
    success: Color(0xFFA9E8C4),
    onSuccess: Color(0xFF083922),
    successBackground: Color(0xFF22392D),
    warning: Color(0xFFFFD48A),
    onWarning: Color(0xFF4D3000),
    warningBackground: Color(0xFF44341C),
    info: Color(0xFFB4D7FF),
    onInfo: Color(0xFF163D65),
    infoBackground: Color(0xFF22364B),
    disabled: Color(0xFFA1ABA6),
    selectedNav: Color(0xFFA9E8C4),
    focusRing: Color(0xFFB4D7FF),
    divider: Color(0xFF8EA099),
    heroBackground: Color(0xFF006151),
    onHero: Colors.white,
    onHeroMuted: Color(0xFFD1EBE4),
    heroSubtle: Color(0xFF9CE9BF),
  );

  @override
  SemanticColors copyWith() => this;

  @override
  SemanticColors lerp(ThemeExtension<SemanticColors>? other, double t) =>
      other is SemanticColors && t >= .5 ? other : this;
}

extension SemanticTheme on BuildContext {
  SemanticColors get semantic => Theme.of(this).extension<SemanticColors>()!;
}

ThemeData appTheme({bool dark = false}) {
  final semantic = dark ? SemanticColors.dark : SemanticColors.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: Palette.teal,
    brightness: dark ? Brightness.dark : Brightness.light,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'KantumruyPro',
    scaffoldBackgroundColor: semantic.surface,
  );
  final text = base.textTheme.copyWith(
    headlineLarge: const TextStyle(
      fontSize: 32,
      height: 1.25,
      fontWeight: FontWeight.w600,
    ),
    headlineMedium: const TextStyle(
      fontSize: 24,
      height: 1.33,
      fontWeight: FontWeight.w600,
    ),
    titleLarge: const TextStyle(
      fontSize: 20,
      height: 1.4,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: const TextStyle(
      fontSize: 18,
      height: 1.44,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: const TextStyle(fontSize: 16, height: 1.5),
    bodyMedium: const TextStyle(fontSize: 14, height: 1.57),
    labelLarge: const TextStyle(
      fontSize: 14,
      height: 1.43,
      fontWeight: FontWeight.w600,
    ),
    bodySmall: const TextStyle(fontSize: 12, height: 1.5),
  );
  return base.copyWith(
    textTheme: text.apply(
      fontFamily: 'KantumruyPro',
      bodyColor: semantic.textPrimary,
      displayColor: semantic.textPrimary,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: semantic.surface,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      elevation: 0,
      titleTextStyle: text.titleLarge?.copyWith(
        color: semantic.textPrimary,
        fontFamily: 'KantumruyPro',
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: semantic.card,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: semantic.divider),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: semantic.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        borderSide: BorderSide(color: semantic.disabled),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x4,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: dark ? semantic.successBackground : Palette.teal,
        foregroundColor: dark ? semantic.textPrimary : Colors.white,
        minimumSize: const Size(AppSize.minTouchTarget, AppSize.primaryControl),
        textStyle: const TextStyle(
          fontFamily: 'KantumruyPro',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.square(AppSize.minTouchTarget),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: semantic.card,
      indicatorColor: semantic.successBackground,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? semantic.selectedNav
              : semantic.textMuted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(
          fontFamily: 'KantumruyPro',
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x6,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.large),
        ),
      ),
    ),
    dividerTheme: DividerThemeData(color: semantic.divider, space: 1),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: semantic.selectedNav,
    ),
    extensions: [semantic],
  );
}
