import 'dart:async';

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_theme.dart';
import '../widgets/info_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const double _horizontalPadding = 24;
  static const double _contentMaxWidth = 440;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _api = ApiService();
  Timer? _refreshTimer;

  bool _loading = true;
  HealthResponse? _health;
  ModelInsightsResponse? _metrics;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _loadAll(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _api.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final health = await _api.fetchHealth();
      final metrics = await _api.fetchModelInsights();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _health = health;
        _metrics = metrics;
        _loadFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _health = null;
        _metrics = null;
        _loadFailed = true;
      });
    }
  }

  /// API row: Online if `status == ok`, else Offline. Failure → Offline.
  String get _apiStatusLabel {
    if (_loading) return '…';
    if (_loadFailed || _health == null) return 'Offline';
    return _health!.status == 'ok' ? 'Online' : 'Offline';
  }

  Color? get _apiStatusColor {
    if (_loading) return AppColors.textTertiary;
    if (_loadFailed || _health == null) return AppColors.danger;
    return _health!.status == 'ok' ? AppColors.success : AppColors.danger;
  }

  /// Model row: Ready if model string present; Not Loaded if empty; Unknown on failure.
  String get _modelStatusLabel {
    if (_loading) return '…';
    if (_loadFailed || _health == null) return 'Unknown';
    final m = _health!.model?.trim();
    if (m != null && m.isNotEmpty) return 'Ready';
    return 'Not Loaded';
  }

  Color? get _modelStatusColor {
    if (_loading) return AppColors.textTertiary;
    if (_loadFailed || _health == null) return AppColors.textTertiary;
    final m = _health!.model?.trim();
    if (m != null && m.isNotEmpty) return AppColors.primaryDark;
    return AppColors.textSecondary;
  }

  String get _validationAccuracyLabel {
    if (_loading) return '…';
    final v = _metrics?.validationAccuracy;
    if (v == null) return 'No training result yet';
    final pct = (v <= 1.01 ? v * 100 : v).clamp(0, 100);
    return '${pct.toStringAsFixed(1)}%';
  }

  int get _healthyCount => _metrics?.classDistribution['healthy'] ?? 0;
  int get _blightCount => _metrics?.classDistribution['bacterial_blight'] ?? 0;

  bool get _apiOnline =>
      !_loading && !_loadFailed && _health != null && _health!.status == 'ok';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - 2 * HomeScreen._horizontalPadding;
        final contentWidth = available > 0
            ? (available > HomeScreen._contentMaxWidth
                ? HomeScreen._contentMaxWidth
                : available)
            : constraints.maxWidth;

        return ColoredBox(
          color: AppColors.background,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              HomeScreen._horizontalPadding,
              20,
              HomeScreen._horizontalPadding,
              32,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: contentWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HomeHeader(theme: theme),
                    const SizedBox(height: 32),
                    _SystemStatusPanel(
                      theme: theme,
                      loading: _loading,
                      apiOnline: _apiOnline,
                      apiStatusLabel: _apiStatusLabel,
                      apiStatusColor: _apiStatusColor,
                      modelStatusLabel: _modelStatusLabel,
                      modelStatusColor: _modelStatusColor,
                      validationAccuracyLabel: _validationAccuracyLabel,
                      healthyCount: _healthyCount,
                      blightCount: _blightCount,
                    ),
                    const SizedBox(height: 36),
                    _OverviewCard(theme: theme),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Centered anchor: icon → title → subtitle with clear vertical rhythm.
class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.theme});

  final TextTheme theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.22),
              width: 1.2,
            ),
            boxShadow: AppShadows.soft,
          ),
          child: Icon(
            Icons.eco_rounded,
            color: AppColors.primaryDark,
            size: 32,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Cassava Detector',
          textAlign: TextAlign.center,
          style: theme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            color: AppColors.textPrimary,
            height: 1.08,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'AI-powered cassava leaf diagnosis and model control.',
          textAlign: TextAlign.center,
          style: theme.bodyLarge?.copyWith(
            color: AppColors.textSecondary,
            height: 1.5,
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

/// Primary panel: stronger tint, green frame, [InfoCard] metrics from `/health`.
class _SystemStatusPanel extends StatelessWidget {
  const _SystemStatusPanel({
    required this.theme,
    required this.loading,
    required this.apiOnline,
    required this.apiStatusLabel,
    required this.apiStatusColor,
    required this.modelStatusLabel,
    required this.modelStatusColor,
    required this.validationAccuracyLabel,
    required this.healthyCount,
    required this.blightCount,
  });

  final TextTheme theme;
  final bool loading;
  final bool apiOnline;
  final String apiStatusLabel;
  final Color? apiStatusColor;
  final String modelStatusLabel;
  final Color? modelStatusColor;
  final String validationAccuracyLabel;
  final int healthyCount;
  final int blightCount;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadii.lg + 2);

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
            spreadRadius: -6,
          ),
          ...AppShadows.card,
        ],
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.28),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 18, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFD8EDE0),
                    AppColors.primaryLight,
                    Color(0xFFF4FAF6),
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                          border: Border.all(
                            color: AppColors.primaryMuted.withValues(alpha: 0.5),
                          ),
                          boxShadow: AppShadows.soft,
                        ),
                        child: Icon(
                          Icons.monitor_heart_rounded,
                          color: AppColors.primaryDark,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'System status',
                              style: theme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.35,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'API, model, validation and binary data coverage',
                              style: theme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _ConnectionBadge(
                        loading: loading,
                        apiOnline: apiOnline,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ColoredBox(
              color: AppColors.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                        child: LinearProgressIndicator(
                          minHeight: 3,
                          backgroundColor: AppColors.borderSubtle,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(12, loading ? 12 : 16, 12, 20),
                    child: Column(
                      children: [
                        InfoCard(
                          title: 'API status',
                          value: apiStatusLabel,
                          icon: Icons.cloud_outlined,
                          valueColor: apiStatusColor,
                        ),
                        const SizedBox(height: 10),
                        InfoCard(
                          title: 'Model status',
                          value: modelStatusLabel,
                          icon: Icons.memory_rounded,
                          valueColor: modelStatusColor,
                        ),
                        const SizedBox(height: 10),
                        InfoCard(
                          title: 'Last validation accuracy',
                          value: validationAccuracyLabel,
                          icon: Icons.show_chart_rounded,
                          valueColor: AppColors.textPrimary,
                        ),
                        const SizedBox(height: 10),
                        InfoCard(
                          title: 'Healthy images',
                          value: '$healthyCount',
                          icon: Icons.favorite_outline_rounded,
                          valueColor: AppColors.primaryDark,
                        ),
                        const SizedBox(height: 10),
                        InfoCard(
                          title: 'Bacterial blight images',
                          value: '$blightCount',
                          icon: Icons.warning_amber_rounded,
                          valueColor: AppColors.warning,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionBadge extends StatelessWidget {
  const _ConnectionBadge({
    required this.loading,
    required this.apiOnline,
  });

  final bool loading;
  final bool apiOnline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    if (loading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Checking',
              style: theme.labelLarge?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      );
    }

    if (apiOnline) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.healthy.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppColors.healthy.withValues(alpha: 0.55),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.healthy.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.healthy,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Live',
              style: theme.labelLarge?.copyWith(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.danger.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 16,
            color: AppColors.danger.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 6),
          Text(
            'Offline',
            style: theme.labelLarge?.copyWith(
              color: AppColors.danger,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Secondary panel: muted canvas + stronger edge vs status card.
class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.theme});

  final TextTheme theme;

  static const _items = [
    (
      Icons.search_rounded,
      'Predict disease from a single leaf photo',
    ),
    (
      Icons.save_alt_rounded,
      'Predicted samples are saved and reused for retraining',
    ),
    (
      Icons.autorenew_rounded,
      'Trigger retraining anytime using already saved data',
    ),
    (
      Icons.dashboard_customize_outlined,
      'Monitor API health and model readiness here',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadii.lg);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: radius,
        border: Border.all(
          color: AppColors.border,
          width: 1.2,
        ),
        boxShadow: AppShadows.soft,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: ColoredBox(
          color: AppColors.sageSoft.withValues(alpha: 0.65),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                        border: Border.all(
                          color: AppColors.primaryMuted.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Icon(
                        Icons.dashboard_rounded,
                        color: AppColors.primaryDark,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Overview',
                            style: theme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'What you can do in this workspace',
                            style: theme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                for (var i = 0; i < _items.length; i++) ...[
                  _OverviewRow(icon: _items[i].$1, text: _items[i].$2),
                  if (i < _items.length - 1) const SizedBox(height: 18),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OverviewRow extends StatelessWidget {
  const _OverviewRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  static const double _iconBox = 44;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: _iconBox,
          height: _iconBox,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.sm),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.12),
              ),
              boxShadow: AppShadows.soft,
            ),
            child: Icon(
              icon,
              size: 22,
              color: AppColors.primaryDark,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ),
      ],
    );
  }
}
