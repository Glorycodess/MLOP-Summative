import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_theme.dart';
import 'app_card.dart';

/// Semantic tone for prediction / health messaging.
enum ResultTone {
  neutral,
  healthy,
  caution,
  alert,
}

class ResultCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? headline;
  final String? metaLine;
  final ResultTone tone;
  final IconData? icon;

  const ResultCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.headline,
    this.metaLine,
    this.tone = ResultTone.neutral,
    this.icon,
  });

  Color get _accent {
    switch (tone) {
      case ResultTone.neutral:
        return AppColors.primary;
      case ResultTone.healthy:
        return AppColors.healthy;
      case ResultTone.caution:
        return AppColors.warning;
      case ResultTone.alert:
        return AppColors.danger;
    }
  }

  Color get _tint {
    switch (tone) {
      case ResultTone.neutral:
        return AppColors.primaryLight;
      case ResultTone.healthy:
        return const Color(0xFFE8F5E9);
      case ResultTone.caution:
        return const Color(0xFFFFF4E5);
      case ResultTone.alert:
        return const Color(0xFFFFEBEE);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            decoration: BoxDecoration(
              color: _tint,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadii.lg),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 14),
                Icon(
                  icon ?? Icons.analytics_outlined,
                  color: _accent,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: theme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (headline != null) ...[
                  Text(
                    headline!,
                    style: theme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: _accent,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                if (metaLine != null) ...[
                  Text(
                    metaLine!,
                    style: theme.labelLarge?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  subtitle,
                  style: theme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact metrics row for retraining / ML readouts.
class MetricsCard extends StatelessWidget {
  const MetricsCard({
    super.key,
    required this.title,
    required this.metrics,
    this.footer,
  });

  final String title;
  final List<MetricItem> metrics;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Row(
              children: [
                Icon(
                  Icons.insights_outlined,
                  size: 22,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: theme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderSubtle),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                for (var i = 0; i < metrics.length; i++) ...[
                  _MetricRow(item: metrics[i]),
                  if (i < metrics.length - 1)
                    const Divider(
                      height: 1,
                      indent: 20,
                      endIndent: 20,
                      color: AppColors.borderSubtle,
                    ),
                ],
              ],
            ),
          ),
          if (footer != null) ...[
            const Divider(height: 1, color: AppColors.borderSubtle),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Text(
                footer!,
                style: theme.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class MetricItem {
  const MetricItem(this.label, this.value, {this.emphasized = false});

  final String label;
  final String value;
  final bool emphasized;
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.item});

  final MetricItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.label,
              style: theme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            item.value,
            style: (item.emphasized ? theme.titleMedium : theme.bodyLarge)
                ?.copyWith(
              fontWeight: FontWeight.w700,
              color: item.emphasized
                  ? AppColors.primary
                  : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
