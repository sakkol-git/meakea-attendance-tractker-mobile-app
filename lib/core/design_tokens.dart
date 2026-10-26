import 'package:flutter/material.dart';

/// Shared layout primitives for HRFlow surfaces and controls.
abstract final class AppSpacing {
  static const x1 = 4.0;
  static const x2 = 8.0;
  static const x3 = 12.0;
  static const x4 = 16.0;
  static const x6 = 24.0;
  static const x8 = 32.0;
  static const x12 = 48.0;
}

abstract final class AppRadius {
  static const small = 6.0;
  static const medium = 12.0;
  static const large = 16.0;
  static const card = 18.0;
  static const pill = 999.0;
}

abstract final class AppSize {
  static const minTouchTarget = 48.0;
  static const primaryControl = 52.0;
  static const contentMax = 760.0;
  static const tabletBreakpoint = 600.0;
}

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 150);
  static const standard = Duration(milliseconds: 220);
}

EdgeInsets pageInsets(BuildContext context, {double bottom = AppSpacing.x8}) {
  final horizontal =
      MediaQuery.sizeOf(context).width >= AppSize.tabletBreakpoint
      ? AppSpacing.x6
      : AppSpacing.x4;
  return EdgeInsets.fromLTRB(horizontal, AppSpacing.x2, horizontal, bottom);
}
