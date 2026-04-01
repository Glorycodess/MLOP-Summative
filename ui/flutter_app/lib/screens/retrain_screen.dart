import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/primary_button.dart';

class RetrainScreen extends StatefulWidget {
  const RetrainScreen({super.key});

  static const double _horizontalPadding = 24;
  static const double _contentMaxWidth = 440;

  @override
  State<RetrainScreen> createState() => _RetrainScreenState();
}

class _RetrainScreenState extends State<RetrainScreen> {
  final ApiService _api = ApiService();

  bool _retraining = false;
  String? _retrainError;
  RetrainResponse? _lastRetrain;

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _retrain() async {
    if (_retraining) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _retraining = true;
      _retrainError = null;
    });
    try {
      final res = await _api.retrainModel();
      if (!mounted) return;
      setState(() {
        _retraining = false;
        _lastRetrain = res;
        _retrainError = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _retraining = false;
        _retrainError = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _retraining = false;
        _retrainError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return ColoredBox(
      color: AppColors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final available =
              constraints.maxWidth - 2 * RetrainScreen._horizontalPadding;
          final contentWidth = available > 0
              ? (available > RetrainScreen._contentMaxWidth
                  ? RetrainScreen._contentMaxWidth
                  : available)
              : constraints.maxWidth;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              RetrainScreen._horizontalPadding,
              16,
              RetrainScreen._horizontalPadding,
              32,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: contentWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _RetrainHeader(theme: theme),
                    const SizedBox(height: 18),
                    _SavedDataHint(theme: theme),
                    const SizedBox(height: 18),
                    PrimaryButton(
                      label: 'Retrain model',
                      icon: Icons.model_training_rounded,
                      variant: AppButtonVariant.filled,
                      isLoading: _retraining,
                      onPressed: _retraining ? null : _retrain,
                    ),
                    const SizedBox(height: 24),
                    _OutcomePanel(
                      theme: theme,
                      retraining: _retraining,
                      lastRetrain: _lastRetrain,
                      retrainError: _retrainError,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RetrainHeader extends StatelessWidget {
  const _RetrainHeader({required this.theme});

  final TextTheme theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 48,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Retrain model',
          textAlign: TextAlign.center,
          style: theme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: AppColors.textPrimary,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Run training on the server using images saved from predictions.',
          textAlign: TextAlign.center,
          style: theme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _OutcomePanel extends StatelessWidget {
  const _OutcomePanel({
    required this.theme,
    required this.retraining,
    required this.lastRetrain,
    required this.retrainError,
  });

  final TextTheme theme;
  final bool retraining;
  final RetrainResponse? lastRetrain;
  final String? retrainError;

  @override
  Widget build(BuildContext context) {
    if (retraining) {
      return AppCard(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        child: Column(
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Training in progress',
              style: theme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'This can take several minutes. Keep the app open.',
              textAlign: TextAlign.center,
              style: theme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    if (retrainError != null && retrainError!.isNotEmpty) {
      return _ErrorOutcomeCard(
        title: 'Retrain failed',
        message: retrainError!,
      );
    }

    if (lastRetrain != null) {
      final r = lastRetrain!;
      final accPct = r.validationAccuracy <= 1.01
          ? r.validationAccuracy * 100
          : r.validationAccuracy;
      return Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: AppShadows.card,
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.insights_rounded,
                  color: AppColors.primaryDark,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Text(
                  'Last run',
                  style: theme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _MetricRow(
              label: 'Status',
              value: r.message,
              emphasizeValue: false,
            ),
            const Divider(height: 22, color: AppColors.borderSubtle),
            _MetricRow(
              label: 'Validation accuracy',
              value: '${accPct.toStringAsFixed(2)}%',
              emphasizeValue: true,
            ),
            const Divider(height: 22, color: AppColors.borderSubtle),
            _MetricRow(
              label: 'Loss',
              value: r.validationLoss.toStringAsFixed(4),
              emphasizeValue: false,
            ),
          ],
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Column(
        children: [
          Icon(
            Icons.play_circle_outline_rounded,
            size: 36,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 12),
          Text(
            'No training run yet',
            style: theme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Run retraining to see the latest metrics.',
            textAlign: TextAlign.center,
            style: theme.bodySmall?.copyWith(
              color: AppColors.textTertiary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedDataHint extends StatelessWidget {
  const _SavedDataHint({required this.theme});

  final TextTheme theme;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.save_alt_rounded,
            size: 20,
            color: AppColors.primaryDark,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Retraining uses samples already saved by the prediction endpoint.',
              style: theme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    required this.emphasizeValue,
  });

  final String label;
  final String value;
  final bool emphasizeValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: (emphasizeValue ? theme.titleMedium : theme.bodyLarge)
                ?.copyWith(
              fontWeight: FontWeight.w800,
              color: emphasizeValue
                  ? AppColors.primaryDark
                  : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorOutcomeCard extends StatelessWidget {
  const _ErrorOutcomeCard({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: AppColors.danger.withValues(alpha: 0.45),
          width: 1.5,
        ),
        boxShadow: AppShadows.soft,
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: AppColors.danger,
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: theme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
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
