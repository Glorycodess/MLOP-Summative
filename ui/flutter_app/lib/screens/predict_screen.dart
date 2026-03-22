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
  static const double _contentMaxWidth = 440;

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

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
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

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              PredictScreen._horizontalPadding,
              16,
              PredictScreen._horizontalPadding,
              32,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: contentWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PredictHeader(theme: theme),
                    const SizedBox(height: 28),
                    _PreviewCard(
                      imageBytes: _imageBytes,
                      theme: theme,
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: 'Select image',
                      icon: Icons.add_photo_alternate_outlined,
                      variant: AppButtonVariant.outline,
                      onPressed: _predictLoading ? null : _pickImage,
                    ),
                    const SizedBox(height: 12),
                    PrimaryButton(
                      label: 'Run prediction',
                      icon: Icons.bolt_rounded,
                      variant: AppButtonVariant.filled,
                      isLoading: _predictLoading,
                      onPressed: (_imageBytes == null ||
                              _imageBytes!.isEmpty ||
                              _predictLoading)
                          ? null
                          : _runPredict,
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
          );
        },
      ),
    );
  }
}

class _PredictHeader extends StatelessWidget {
  const _PredictHeader({required this.theme});

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
        const SizedBox(height: 20),
        Text(
          'Predict disease',
          textAlign: TextAlign.center,
          style: theme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: AppColors.textPrimary,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Capture a cassava leaf — the model returns class and confidence.',
          textAlign: TextAlign.center,
          style: theme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            height: 1.45,
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
  });

  final Uint8List? imageBytes;
  final TextTheme theme;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageBytes != null && imageBytes!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 14),
            spreadRadius: -8,
          ),
          ...AppShadows.card,
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.xl - 1),
        child: AspectRatio(
          aspectRatio: 4 / 3,
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
                  color: AppColors.primaryLight.withValues(alpha: 0.55),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              width: 2,
                            ),
                            boxShadow: AppShadows.soft,
                          ),
                          child: Icon(
                            Icons.document_scanner_rounded,
                            size: 44,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No leaf photo yet',
                          textAlign: TextAlign.center,
                          style: theme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Select a clear photo of a cassava leaf to run inference.',
                          textAlign: TextAlign.center,
                          style: theme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
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
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        child: Column(
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Analyzing leaf…',
              style: theme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Sending image to the API and reading the model output.',
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

    if (result != null) {
      final r = result!;
      final tone = _toneForClass(r.prediction);
      final label = _formatClassLabel(r.prediction);
      final pct = (r.confidence * 100).clamp(0, 100);
      return ResultCard(
        title: 'Prediction',
        headline: label,
        metaLine: 'Confidence ${pct.toStringAsFixed(1)}%',
        subtitle: _interpretation(r.prediction, label),
        tone: tone,
        icon: tone == ResultTone.healthy
            ? Icons.verified_rounded
            : Icons.warning_amber_rounded,
      );
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
      child: Column(
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 36,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 12),
          Text(
            'No result yet',
            style: theme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose a photo and run prediction to see class and confidence.',
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

class _ErrorResultCard extends StatelessWidget {
  const _ErrorResultCard({required this.message});

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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: AppColors.danger,
              size: 28,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prediction failed',
                    style: theme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
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
      ),
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
    return 'The model classifies this leaf as healthy with the stated confidence. Continue routine monitoring in the field.';
  }
  return 'The model suggests $displayLabel with the stated confidence. Verify with an agronomist and consider follow-up scouting.';
}
