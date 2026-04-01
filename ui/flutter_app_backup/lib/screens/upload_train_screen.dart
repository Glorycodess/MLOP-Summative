import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/primary_button.dart';

class UploadTrainScreen extends StatefulWidget {
  const UploadTrainScreen({super.key});

  static const double _horizontalPadding = 24;
  static const double _contentMaxWidth = 440;

  static const _labels = [
    'healthy',
    'bacterial_blight',
  ];

  @override
  State<UploadTrainScreen> createState() => _UploadTrainScreenState();
}

class _UploadTrainScreenState extends State<UploadTrainScreen> {
  final ApiService _api = ApiService();
  final ImagePicker _picker = ImagePicker();

  String _selectedLabel = UploadTrainScreen._labels.first;
  List<XFile> _picked = [];

  bool _busy = false;
  String? _error;
  String? _note;
  RetrainResponse? _lastTrain;

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_busy) return;
    try {
      final imgs = await _picker.pickMultiImage(imageQuality: 85);
      if (!mounted) return;
      setState(() {
        _picked = imgs;
        _error = null;
        _note = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _uploadAndTrain() async {
    if (_busy || _picked.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _note = null;
      _lastTrain = null;
    });

    try {
      final parts = <({List<int> bytes, String filename})>[];
      for (final x in _picked) {
        final bytes = await x.readAsBytes();
        parts.add((bytes: bytes, filename: x.name));
      }

      final uploadRes = await _api.uploadTrainingData(
        label: _selectedLabel,
        files: parts,
      );

      final trainRes = await _api.retrainModel();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _note = uploadRes.message;
        _lastTrain = trainRes;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
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
              constraints.maxWidth - 2 * UploadTrainScreen._horizontalPadding;
          final contentWidth = available > 0
              ? (available > UploadTrainScreen._contentMaxWidth
                  ? UploadTrainScreen._contentMaxWidth
                  : available)
              : constraints.maxWidth;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              UploadTrainScreen._horizontalPadding,
              16,
              UploadTrainScreen._horizontalPadding,
              32,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: contentWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _UploadTrainHeader(theme: theme),
                    const SizedBox(height: 22),
                    _LabelPicker(
                      theme: theme,
                      value: _selectedLabel,
                      onChanged: _busy
                          ? null
                          : (v) {
                              if (v != null) {
                                setState(() => _selectedLabel = v);
                              }
                            },
                    ),
                    const SizedBox(height: 16),
                    _FilesCard(
                      theme: theme,
                      picked: _picked,
                      busy: _busy,
                      note: _note,
                      onPick: _pickImages,
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: 'Upload & Train',
                      icon: Icons.auto_fix_high_rounded,
                      variant: AppButtonVariant.filled,
                      isLoading: _busy,
                      onPressed:
                          (!_busy && _picked.isNotEmpty) ? _uploadAndTrain : null,
                    ),
                    const SizedBox(height: 24),
                    _UploadTrainOutcome(
                      theme: theme,
                      busy: _busy,
                      error: _error,
                      lastTrain: _lastTrain,
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

class _UploadTrainHeader extends StatelessWidget {
  const _UploadTrainHeader({required this.theme});

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
          'Upload & train',
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
          'Add labeled photos once. Retraining can be run later without re-uploading.',
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

class _LabelPicker extends StatelessWidget {
  const _LabelPicker({
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
            'LABEL',
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
                items: UploadTrainScreen._labels
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

class _FilesCard extends StatelessWidget {
  const _FilesCard({
    required this.theme,
    required this.picked,
    required this.busy,
    required this.note,
    required this.onPick,
  });

  final TextTheme theme;
  final List<XFile> picked;
  final bool busy;
  final String? note;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final n = picked.length;
    final previewNames = picked.take(3).map((x) => x.name).join(', ');
    final extra = n > 3 ? ' +${n - 3} more' : '';

    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      borderRadius: BorderRadius.circular(AppRadii.lg),
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
                  Icons.photo_library_outlined,
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
                      n == 0 ? 'No files selected' : '$n selected',
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
          if (note != null && note!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              note!,
              style: theme.bodySmall?.copyWith(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Choose images',
            icon: Icons.folder_open_rounded,
            variant: AppButtonVariant.outline,
            onPressed: busy ? null : onPick,
          ),
        ],
      ),
    );
  }
}

class _UploadTrainOutcome extends StatelessWidget {
  const _UploadTrainOutcome({
    required this.theme,
    required this.busy,
    required this.error,
    required this.lastTrain,
  });

  final TextTheme theme;
  final bool busy;
  final String? error;
  final RetrainResponse? lastTrain;

  @override
  Widget build(BuildContext context) {
    if (busy) {
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
              'Uploading & training…',
              style: theme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      );
    }

    if (error != null && error!.isNotEmpty) {
      return _InlineError(message: error!);
    }

    if (lastTrain != null) {
      final r = lastTrain!;
      final accPct =
          r.validationAccuracy <= 1.01 ? r.validationAccuracy * 100 : r.validationAccuracy;
      return AppCard(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Training complete',
              style: theme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              r.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Validation accuracy: ${accPct.toStringAsFixed(2)}%',
              style: theme.bodyMedium?.copyWith(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Validation loss: ${r.validationLoss.toStringAsFixed(4)}',
              style: theme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
      child: Column(
        children: [
          Icon(
            Icons.cloud_upload_outlined,
            size: 34,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 10),
          Text(
            'Choose images to upload and train.',
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
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

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
            child: Text(
              message,
              style: theme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

