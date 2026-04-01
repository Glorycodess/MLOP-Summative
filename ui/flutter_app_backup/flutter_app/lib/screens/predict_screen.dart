import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/primary_button.dart';
import '../widgets/result_card.dart';

class PredictScreen extends StatefulWidget {
  const PredictScreen({super.key});

  static const double _horizontalPadding = 24;
  static const double _contentMaxWidth = 420;

  @override
  State<PredictScreen> createState() => _PredictScreenState();
}

class _PredictScreenState extends State<PredictScreen> {
  final ApiService _api = ApiService();
  final ImagePicker _picker = ImagePicker();

  Uint8List? _imageBytes;
  String _imageName = '';
  bool _predictLoading = false;
  PredictResponse? _result;
  String? _errorMessage;

  bool _insightsLoading = true;
  /// True after a failed insights fetch (e.g. 404) — show a minimal hint, not an error panel.
  bool _insightsUnavailable = false;
  ModelInsightsResponse? _insights;

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _loadInsights() async {
    if (!mounted) return;
    setState(() {
      _insightsLoading = true;
      _insightsUnavailable = false;
    });
    try {
      final r = await _api.fetchModelInsights();
      if (!mounted) return;
      setState(() {
        _insights = r;
        _insightsLoading = false;
        _insightsUnavailable = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() {
        _insightsLoading = false;
        _insightsUnavailable = true;
        _insights = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _insightsLoading = false;
        _insightsUnavailable = true;
        _insights = null;
      });
    }
  }

  Future<void> _pickImage() async {
    if (_predictLoading) return;
    try {
      final x = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
      );
      if (x == null || !mounted) return;
      final bytes = await x.readAsBytes();
      setState(() {
        _imageBytes = Uint8List.fromList(bytes);
        _imageName = x.name;
        _result = null;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not open the photo library: $e';
        _result = null;
      });
    }
  }

  Future<void> _runPredict() async {
    final bytes = _imageBytes;
    if (bytes == null || bytes.isEmpty || _predictLoading) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _predictLoading = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final response = await _api.predictImage(
        imageBytes: bytes,
        filename: _imageName,
      );
      if (!mounted) return;
      setState(() {
        _predictLoading = false;
        _result = response;
        _errorMessage = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _predictLoading = false;
        _result = null;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _predictLoading = false;
        _result = null;
        _errorMessage = e.toString();
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
              constraints.maxWidth - 2 * PredictScreen._horizontalPadding;
          final contentWidth = available > 0
              ? (available > PredictScreen._contentMaxWidth
                  ? PredictScreen._contentMaxWidth
                  : available)
              : constraints.maxWidth;
          final insightsPanelWidth = math.max(
            0.0,
            constraints.maxWidth - 2 * PredictScreen._horizontalPadding,
          );
          const sideBySideMinWidth = 560.0;
          final insightsSideBySide = insightsPanelWidth >= sideBySideMinWidth;

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              PredictScreen._horizontalPadding,
              20,
              PredictScreen._horizontalPadding,
              36,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: contentWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ScreenHeader(theme: theme),
                        const SizedBox(height: 32),
                        _PreviewCard(
                          imageBytes: _imageBytes,
                          theme: theme,
                          predictLoading: _predictLoading,
                          onPickImage: _pickImage,
                          onPredict: _runPredict,
                        ),
                        const SizedBox(height: 28),
                        _ResultSection(
                          theme: theme,
                          loading: _predictLoading,
                          result: _result,
                          errorMessage: _errorMessage,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                _PredictInsightsPanel(
                  sideBySide: insightsSideBySide,
                  loading: _insightsLoading,
                  unavailable: _insightsUnavailable,
                  insights: _insights,
                  onRetry: _loadInsights,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ScreenHeader extends StatelessWidget {
  const _ScreenHeader({required this.theme});

  final TextTheme theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Predict disease',
          textAlign: TextAlign.center,
          style: theme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
            color: AppColors.textPrimary,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'A clear leaf photo is enough for a quick read on class and confidence.',
          textAlign: TextAlign.center,
          style: theme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            height: 1.5,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.imageBytes,
    required this.theme,
    required this.predictLoading,
    required this.onPickImage,
    required this.onPredict,
  });

  final Uint8List? imageBytes;
  final TextTheme theme;
  final bool predictLoading;
  final VoidCallback onPickImage;
  final VoidCallback onPredict;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageBytes != null && imageBytes!.isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        const narrowActionBreakpoint = 380.0;
        final useStackedActions = maxW < narrowActionBreakpoint;

        return AppCard(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
          borderRadius: BorderRadius.circular(AppRadii.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: hasImage
                          ? ColoredBox(
                              color: AppColors.surface,
                              child: Image.memory(
                                imageBytes!,
                                fit: BoxFit.contain,
                                gaplessPlayback: true,
                              ),
                            )
                          : ColoredBox(
                              color: AppColors.sageSoft,
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 28,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.photo_outlined,
                                        size: 48,
                                        color: AppColors.primary.withValues(
                                          alpha: 0.55,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Add a leaf photo',
                                        textAlign: TextAlign.center,
                                        style: theme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: useStackedActions ? 16 : 20),
              if (useStackedActions)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PrimaryButton(
                      label: 'Select',
                      icon: Icons.add_photo_alternate_outlined,
                      variant: AppButtonVariant.outline,
                      onPressed: predictLoading ? null : onPickImage,
                    ),
                    const SizedBox(height: 10),
                    PrimaryButton(
                      label: 'Predict',
                      icon: Icons.bolt_rounded,
                      variant: AppButtonVariant.filled,
                      isLoading: predictLoading,
                      onPressed: (imageBytes == null ||
                              imageBytes!.isEmpty ||
                              predictLoading)
                          ? null
                          : onPredict,
                    ),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: PrimaryButton(
                        label: 'Select',
                        icon: Icons.add_photo_alternate_outlined,
                        variant: AppButtonVariant.outline,
                        onPressed: predictLoading ? null : onPickImage,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PrimaryButton(
                        label: 'Predict',
                        icon: Icons.bolt_rounded,
                        variant: AppButtonVariant.filled,
                        isLoading: predictLoading,
                        onPressed: (imageBytes == null ||
                                imageBytes!.isEmpty ||
                                predictLoading)
                            ? null
                            : onPredict,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ResultSection extends StatelessWidget {
  const _ResultSection({
    required this.theme,
    required this.loading,
    required this.result,
    required this.errorMessage,
  });

  final TextTheme theme;
  final bool loading;
  final PredictResponse? result;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    if (errorMessage != null && errorMessage!.isNotEmpty) {
      return _ErrorResultCard(message: errorMessage!);
    }

    if (loading) {
      return AppCard(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        child: Column(
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 2.8,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Analyzing your leaf',
              style: theme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Almost there.',
              style: theme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    if (result != null) {
      final r = result!;
      final tone = _toneForClass(r.prediction);
      final label = _formatClassLabel(r.prediction);
      final pct = (r.confidence * 100).clamp(0, 100);
      return ResultCard(
        title: 'Result',
        headline: label,
        metaLine: '${pct.toStringAsFixed(1)}% confidence',
        subtitle: _interpretation(r.prediction, label),
        tone: tone,
        icon: tone == ResultTone.healthy
            ? Icons.spa_rounded
            : Icons.eco_rounded,
      );
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      borderRadius: BorderRadius.circular(AppRadii.xl),
      child: Column(
        children: [
          Icon(
            Icons.insert_chart_outlined_rounded,
            size: 36,
            color: AppColors.textTertiary.withValues(alpha: 0.85),
          ),
          const SizedBox(height: 14),
          Text(
            'Your result will appear here',
            textAlign: TextAlign.center,
            style: theme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorResultCard extends StatelessWidget {
  const _ErrorResultCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      borderRadius: BorderRadius.circular(AppRadii.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: AppColors.danger.withValues(alpha: 0.9),
            size: 26,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Something went wrong',
                  style: theme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
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

class _PredictInsightsPanel extends StatelessWidget {
  const _PredictInsightsPanel({
    required this.sideBySide,
    required this.loading,
    required this.unavailable,
    required this.insights,
    required this.onRetry,
  });

  final bool sideBySide;
  final bool loading;
  final bool unavailable;
  final ModelInsightsResponse? insights;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return _InsightsLoadingLayout(sideBySide: sideBySide);
    }
    final data = insights;
    if (unavailable || data == null) {
      return _InsightsUnavailableHint(onRetry: onRetry);
    }

    final classCard = _ClassDistributionCard(counts: data.classDistribution);
    final accCard = _ModelAccuracyCard(validationAccuracy: data.validationAccuracy);

    if (sideBySide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: classCard),
          const SizedBox(width: 20),
          Expanded(child: accCard),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        classCard,
        const SizedBox(height: 20),
        accCard,
      ],
    );
  }
}

/// Minimal line when the insights endpoint is missing or unreachable (e.g. 404).
class _InsightsUnavailableHint extends StatelessWidget {
  const _InsightsUnavailableHint({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: [
          Icon(
            Icons.insights_outlined,
            size: 17,
            color: AppColors.textTertiary.withValues(alpha: 0.95),
          ),
          Text(
            'Insights unavailable',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.bodySmall?.copyWith(
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Retry',
              style: theme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightsLoadingLayout extends StatelessWidget {
  const _InsightsLoadingLayout({required this.sideBySide});

  final bool sideBySide;

  @override
  Widget build(BuildContext context) {
    const card = _InsightSkeletonCard();
    if (sideBySide) {
      return const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: card),
          SizedBox(width: 20),
          Expanded(child: card),
        ],
      );
    }
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card,
        SizedBox(height: 20),
        card,
      ],
    );
  }
}

class _InsightSkeletonCard extends StatelessWidget {
  const _InsightSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      borderRadius: BorderRadius.circular(AppRadii.xl),
      child: Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 2.8,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _ClassDistributionCard extends StatelessWidget {
  const _ClassDistributionCard({required this.counts});

  final Map<String, int> counts;

  static const List<Color> _barColors = [
    Color(0xFF1B4332),
    Color(0xFF2D6A4F),
    Color(0xFF40916C),
    Color(0xFF52B788),
    Color(0xFF74C69D),
    Color(0xFF95D5B2),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return AppCard(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      borderRadius: BorderRadius.circular(AppRadii.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InsightCardTitle(
            title: 'Class distribution',
            icon: Icons.stacked_bar_chart_rounded,
          ),
          const SizedBox(height: 22),
          if (total <= 0 || entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Text(
                'No data available',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.bodyMedium?.copyWith(
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, c) {
                final labelW = (c.maxWidth * 0.36).clamp(96.0, 148.0);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < entries.length; i++) ...[
                      if (i > 0) const SizedBox(height: 14),
                      _DistributionBarRow(
                        label: _formatClassLabel(entries[i].key),
                        fraction: entries[i].value / total,
                        color: _barColors[i % _barColors.length],
                        labelWidth: labelW,
                      ),
                    ],
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _DistributionBarRow extends StatelessWidget {
  const _DistributionBarRow({
    required this.label,
    required this.fraction,
    required this.color,
    required this.labelWidth,
  });

  final String label;
  final double fraction;
  final Color color;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final pct = (fraction * 100).clamp(0.0, 100.0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: theme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 12,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: AppColors.primaryLight.withValues(alpha: 0.45)),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: fraction.clamp(0.0, 1.0),
                      heightFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              color,
                              color.withValues(alpha: 0.82),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 44,
          child: Text(
            '${pct.round()}%',
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: theme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
        ),
      ],
    );
  }
}

class _ModelAccuracyCard extends StatelessWidget {
  const _ModelAccuracyCard({required this.validationAccuracy});

  final double? validationAccuracy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final acc = validationAccuracy;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      borderRadius: BorderRadius.circular(AppRadii.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InsightCardTitle(
            title: 'Model accuracy',
            icon: Icons.percent_rounded,
          ),
          const SizedBox(height: 20),
          if (acc == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No data available',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.bodyMedium?.copyWith(
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, c) {
                final ring = (c.maxWidth * 0.38).clamp(104.0, 128.0);
                final p = acc.clamp(0.0, 1.0);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: ring,
                      height: ring,
                      child: CustomPaint(
                        painter: _AccuracyRingPainter(progress: p),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${(p * 100).toStringAsFixed(1)}%',
                              maxLines: 1,
                              style: theme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.8,
                                color: AppColors.primaryDark,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Validation accuracy',
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: theme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _AccuracyRingPainter extends CustomPainter {
  _AccuracyRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = 9.0;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - stroke) / 2;

    final track = Paint()
      ..color = AppColors.primaryLight.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final fill = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi,
      false,
      track,
    );

    final sweep = (2 * math.pi * progress).clamp(0.0, 2 * math.pi);
    if (sweep > 0.001) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweep,
        false,
        fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AccuracyRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _InsightCardTitle extends StatelessWidget {
  const _InsightCardTitle({
    required this.title,
    required this.icon,
  });

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 14),
        Icon(icon, size: 24, color: AppColors.primaryDark),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: theme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

ResultTone _toneForClass(String raw) {
  if (raw.toLowerCase().trim() == 'healthy') {
    return ResultTone.healthy;
  }
  return ResultTone.caution;
}

String _formatClassLabel(String raw) {
  final parts = raw.split('_').where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return raw;
  return parts
      .map(
        (w) =>
            '${w[0].toUpperCase()}${w.length > 1 ? w.substring(1).toLowerCase() : ''}',
      )
      .join(' ');
}

String _interpretation(String rawClass, String displayLabel) {
  if (rawClass.toLowerCase().trim() == 'healthy') {
    return 'Healthy-looking leaf at this confidence. Keep an eye on the crop as usual.';
  }
  return 'Possible $displayLabel. Use this as a hint and confirm in the field if unsure.';
}
