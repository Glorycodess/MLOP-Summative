import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_theme.dart';

enum AppButtonVariant { filled, tonal, outline }

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final AppButtonVariant variant;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.variant = AppButtonVariant.filled,
  });

  static const double _height = 52;

  @override
  Widget build(BuildContext context) {
    final Widget? leading = _leading();

    switch (variant) {
      case AppButtonVariant.filled:
        return SizedBox(
          width: double.infinity,
          height: _height,
          child: ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              shadowColor: Colors.transparent,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.primaryMuted.withValues(alpha: 0.45),
              disabledForegroundColor: Colors.white70,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            child: _ButtonLabelRow(
              label: label,
              leading: leading,
              showTrailingArrow: icon == null && !isLoading,
            ),
          ),
        );
      case AppButtonVariant.tonal:
        return SizedBox(
          width: double.infinity,
          height: _height,
          child: FilledButton.tonal(
            onPressed: isLoading ? null : onPressed,
            style: FilledButton.styleFrom(
              elevation: 0,
              backgroundColor: AppColors.primaryLight,
              foregroundColor: AppColors.primaryDark,
              disabledBackgroundColor: AppColors.surfaceMuted,
              disabledForegroundColor: AppColors.textTertiary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            child: _ButtonLabelRow(
              label: label,
              leading: leading,
              showTrailingArrow: icon == null && !isLoading,
            ),
          ),
        );
      case AppButtonVariant.outline:
        return SizedBox(
          width: double.infinity,
          height: _height,
          child: OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              disabledForegroundColor: AppColors.textTertiary,
              side: const BorderSide(color: AppColors.border, width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            child: _ButtonLabelRow(
              label: label,
              leading: leading,
              showTrailingArrow: icon == null && !isLoading,
            ),
          ),
        );
    }
  }

  Widget? _leading() {
    if (isLoading) {
      switch (variant) {
        case AppButtonVariant.filled:
          return const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          );
        case AppButtonVariant.tonal:
        case AppButtonVariant.outline:
          return const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          );
      }
    }
    if (icon != null) {
      return Icon(icon, size: 22);
    }
    return null;
  }
}

class _ButtonLabelRow extends StatelessWidget {
  const _ButtonLabelRow({
    required this.label,
    required this.showTrailingArrow,
    this.leading,
  });

  final String label;
  final Widget? leading;
  final bool showTrailingArrow;

  @override
  Widget build(BuildContext context) {
    final textStyle = const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    );

    if (leading != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          leading!,
          const SizedBox(width: 10),
          Text(label, style: textStyle),
        ],
      );
    }

    if (showTrailingArrow) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: textStyle),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_rounded, size: 20),
        ],
      );
    }

    return Text(label, style: textStyle);
  }
}
