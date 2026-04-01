import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

/// Consistent page title + subtitle rhythm for inner screens.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.badge,
  });

  final String title;
  final String subtitle;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: AppColors.textPrimary,
                  height: 1.15,
                ),
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              badge!,
            ],
          ],
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          style: theme.bodyLarge?.copyWith(
            color: AppColors.textSecondary,
            height: 1.45,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
