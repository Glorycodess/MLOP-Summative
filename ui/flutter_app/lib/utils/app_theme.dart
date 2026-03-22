import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Shared radii, shadows, and layout tokens — standard Flutter only.
class AppRadii {
  AppRadii._();

  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 22;
}

class AppShadows {
  AppShadows._();

  static List<BoxShadow> get card => [
        BoxShadow(
          color: AppColors.shadow,
          blurRadius: 20,
          offset: const Offset(0, 6),
          spreadRadius: -4,
        ),
      ];

  static List<BoxShadow> get soft => [
        BoxShadow(
          color: AppColors.shadow.withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get nav => [
        BoxShadow(
          color: AppColors.shadow.withValues(alpha: 0.08),
          blurRadius: 16,
          offset: const Offset(0, -4),
        ),
      ];
}
