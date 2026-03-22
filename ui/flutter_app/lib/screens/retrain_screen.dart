import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/primary_button.dart';

class RetrainScreen extends StatefulWidget {
  const RetrainScreen({super.key});

  static const double _horizontalPadding = 24;
  static const double _contentMaxWidth = 440;

  static const _labels = [
    'healthy',
    'bacterial_blight',
    'brown_streak',
    'green_mottle',
    'mosaic',
  ];

  @override
  State<RetrainScreen> createState() => _RetrainScreenState();
}

class _RetrainScreenState extends State<RetrainScreen> {
  final ApiService _api = ApiService();
  final ImagePicker _picker = ImagePicker();

  String _selectedLabel = RetrainScreen._labels.first;
  List<XFile> _picked = [];
  bool _uploading = false;
  bool _retraining = false;
  String? _uploadNote;
  String? _uploadError;
  String? _retrainError;
  RetrainResponse? _lastRetrain;

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_uploading || _retraining) return;
    try {
      final imgs = await _picker.pickMultiImage(imageQuality: 85);
      if (!mounted) return;
      setState(() {
        _picked = imgs;
        _uploadNote = null;
        _uploadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadError = e.toString();
      });
    }
  }

  Future<void> _upload() async {
    if (_picked.isEmpty || _uploading || _retraining) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _uploading = true;
      _uploadError = null;
      _uploadNote = null;
    });
    try {
      final parts = <({List<int> bytes, String filename})>[];
      for (final x in _picked) {
        final bytes = await x.readAsBytes();
        parts.add((bytes: bytes, filename: x.name));
      }
      final res = await _api.uploadTrainingData(
        label: _selectedLabel,
        files: parts,
      );
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _uploadNote = res.message;
        _uploadError = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _uploadError = e.message;
        _uploadNote = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _uploadError = e.toString();
        _uploadNote = null;
      });
    }
  }

  Future<void> _retrain() async {
    if (_uploading || _retraining) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _retraining = true;
      _retrainError = null;
      _uploadError = null;
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
                    const SizedBox(height: 22),
                    _LabelCard(
                      theme: theme,
                      value: _selectedLabel,
                      onChanged: (_uploading || _retraining)
                          ? null
                          : (v) {
                              if (v != null) {
                                setState(() => _selectedLabel = v);
                              }
                            },
                    ),
                    const SizedBox(height: 16),
                    _UploadCard(
                      theme: theme,
                      picked: _picked,
                      uploading: _uploading,
                      uploadNote: _uploadNote,
                      onPick: _pickImages,
                      onUpload: _upload,
                      pickEnabled: !_uploading && !_retraining,
                      uploadEnabled: _picked.isNotEmpty &&
                          !_uploading &&
                          !_retraining,
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: 'Retrain model',
                      icon: Icons.model_training_rounded,
                      variant: AppButtonVariant.filled,
                      isLoading: _retraining,
                      onPressed:
                          (_uploading || _retraining) ? null : _retrain,
                    ),
                    const SizedBox(height: 24),
                    _OutcomePanel(
                      theme: theme,
                      retraining: _retraining,
                      lastRetrain: _lastRetrain,
                      uploadError: _uploadError,
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
          'Upload labeled images, then run training on the server.',
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

class _LabelCard extends StatelessWidget {
  const _LabelCard({
    required this.theme,
    required this.value,
    required this.onChanged,
  });

  final TextTheme theme;
  final String value;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
          width: 2,
        ),
        boxShadow: AppShadows.soft,
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'CLASS LABEL',
            style: theme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surfaceMuted,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.md),
                borderSide: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.25),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.md),
                borderSide: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.25),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.md),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                borderRadius: BorderRadius.circular(AppRadii.md),
                dropdownColor: AppColors.surface,
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.primaryDark,
                ),
                style: theme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                items: RetrainScreen._labels
                    .map(
                      (l) => DropdownMenuItem(
                        value: l,
                        child: Text(l),
                      ),
                    )
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadCard extends StatelessWidget {
  const _UploadCard({
    required this.theme,
    required this.picked,
    required this.uploading,
    required this.uploadNote,
    required this.onPick,
    required this.onUpload,
    required this.pickEnabled,
    required this.uploadEnabled,
  });

  final TextTheme theme;
  final List<XFile> picked;
  final bool uploading;
  final String? uploadNote;
  final VoidCallback onPick;
  final VoidCallback onUpload;
  final bool pickEnabled;
  final bool uploadEnabled;

  @override
  Widget build(BuildContext context) {
    final n = picked.length;
    final previewNames = picked.take(3).map((x) => x.name).join(', ');
    final extra = n > 3 ? ' +${n - 3} more' : '';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
            spreadRadius: -6,
          ),
          ...AppShadows.soft,
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Icon(
                  Icons.folder_open_rounded,
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
                      'IMAGES',
                      style: theme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      n == 0
                          ? 'No files selected'
                          : '$n file${n == 1 ? '' : 's'}',
                      style: theme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (n > 0) ...[
            const SizedBox(height: 10),
            Text(
              '$previewNames$extra',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ],
          if (uploadNote != null && uploadNote!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              uploadNote!,
              style: theme.bodySmall?.copyWith(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (uploading) ...[
            const SizedBox(height: 14),
            const ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(4)),
              child: LinearProgressIndicator(
                minHeight: 3,
                backgroundColor: AppColors.borderSubtle,
                color: AppColors.primary,
              ),
            ),
          ],
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Choose images',
            icon: Icons.photo_library_outlined,
            variant: AppButtonVariant.outline,
            onPressed: pickEnabled ? onPick : null,
          ),
          const SizedBox(height: 10),
          PrimaryButton(
            label: 'Upload',
            icon: Icons.cloud_upload_outlined,
            variant: AppButtonVariant.tonal,
            isLoading: uploading,
            onPressed: uploadEnabled && !uploading ? onUpload : null,
          ),
        ],
      ),
    );
  }
}

class _OutcomePanel extends StatelessWidget {
  const _OutcomePanel({
    required this.theme,
    required this.retraining,
    required this.lastRetrain,
    required this.uploadError,
    required this.retrainError,
  });

  final TextTheme theme;
  final bool retraining;
  final RetrainResponse? lastRetrain;
  final String? uploadError;
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

    if (uploadError != null && uploadError!.isNotEmpty) {
      return _ErrorOutcomeCard(
        title: 'Upload failed',
        message: uploadError!,
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
            'Upload, then retrain to see metrics.',
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
