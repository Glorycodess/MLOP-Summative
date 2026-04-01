import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/constants.dart';

double _asDouble(dynamic v, {double fallback = 0}) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim()) ?? fallback;
  return fallback;
}

/// Response body from `GET /health`.
class HealthResponse {
  const HealthResponse({
    required this.status,
    this.model,
    this.message,
  });

  final String status;
  final String? model;
  final String? message;

  factory HealthResponse.fromJson(Map<String, dynamic> json) {
    return HealthResponse(
      status: json['status'] as String? ?? '',
      model: json['model'] as String?,
      message: json['message'] as String?,
    );
  }
}

/// `GET /metrics` — class counts on disk + last retrain validation accuracy.
class ModelInsightsResponse {
  const ModelInsightsResponse({
    required this.classDistribution,
    this.validationAccuracy,
  });

  /// Display label -> image count (merged training folders).
  final Map<String, int> classDistribution;

  /// 0.0–1.0 from last retrain, or null if never persisted.
  final double? validationAccuracy;

  factory ModelInsightsResponse.fromJson(Map<String, dynamic> json) {
    final map = <String, int>{};
    final raw = json['class_distribution'];
    if (raw is Map) {
      for (final e in raw.entries) {
        final k = e.key;
        final v = e.value;
        if (k is String && v is num) {
          map[k] = v.round();
        } else if (k is String && v is String) {
          map[k] = int.tryParse(v.trim()) ?? 0;
        }
      }
    }

    double? acc;
    final a = json['validation_accuracy'];
    if (a != null) {
      acc = _asDouble(a);
    }

    return ModelInsightsResponse(
      classDistribution: map,
      validationAccuracy: acc,
    );
  }
}

/// Response body from `POST /predict` (matches FastAPI `predict` route).
class PredictResponse {
  const PredictResponse({
    required this.filename,
    required this.prediction,
    required this.confidence,
  });

  final String filename;
  final String prediction;
  final double confidence;

  factory PredictResponse.fromJson(Map<String, dynamic> json) {
    final c = _asDouble(json['confidence']);
    return PredictResponse(
      filename: json['filename'] as String? ?? '',
      prediction: json['prediction'] as String? ?? 'unknown',
      confidence: c,
    );
  }
}

class ApiService {
  ApiService({http.Client? client})
      : _client = client ?? http.Client(),
        _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  /// Calls `GET {baseUrl}/health`.
  Future<HealthResponse> fetchHealth() async {
    final uri = Uri.parse('${AppConstants.baseUrl}/health');
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw ApiException(
        'Health check failed (${response.statusCode})',
      );
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw ApiException('Invalid health response');
    }

    return HealthResponse.fromJson(decoded);
  }

  /// `GET {baseUrl}/metrics` — dataset class counts and persisted val accuracy.
  Future<ModelInsightsResponse> fetchModelInsights() async {
    final uri = Uri.parse('${AppConstants.baseUrl}/metrics');
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw ApiException(
        'Insights request failed (${response.statusCode})',
      );
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw ApiException('Invalid insights response');
    }

    return ModelInsightsResponse.fromJson(decoded);
  }

  /// Multipart `POST {baseUrl}/predict` with form field `file` (FastAPI `UploadFile`).
  Future<PredictResponse> predictImage({
    required List<int> imageBytes,
    required String filename,
  }) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/predict');
    final request = http.MultipartRequest('POST', uri);
    final safeName =
        filename.trim().isEmpty ? 'cassava_leaf.jpg' : filename.trim();
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: safeName,
      ),
    );

    final streamed = await _client
        .send(request)
        .timeout(const Duration(seconds: 90));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw ApiException(
        _parseErrorBody(
          response.body,
          response.statusCode,
          fallback: 'Prediction failed',
        ),
      );
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw ApiException('Invalid prediction response');
    }

    return PredictResponse.fromJson(decoded);
  }

  /// Multipart `POST {baseUrl}/upload-data?label=...` with repeated `files` parts.
  Future<UploadDataResponse> uploadTrainingData({
    required String label,
    required List<({List<int> bytes, String filename})> files,
  }) async {
    if (files.isEmpty) {
      throw ApiException('No files to upload');
    }

    // FastAPI may bind `label` as query or form depending on version; send both.
    final uri = Uri.parse('${AppConstants.baseUrl}/upload-data').replace(
      queryParameters: {'label': label},
    );
    final request = http.MultipartRequest('POST', uri);
    request.fields['label'] = label;

    for (final f in files) {
      final name =
          f.filename.trim().isEmpty ? 'image.jpg' : f.filename.trim();
      request.files.add(
        http.MultipartFile.fromBytes(
          'files',
          f.bytes,
          filename: name,
        ),
      );
    }

    final streamed = await _client
        .send(request)
        .timeout(const Duration(minutes: 3));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw ApiException(
        _parseErrorBody(
          response.body,
          response.statusCode,
          fallback: 'Upload failed',
        ),
      );
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw ApiException('Invalid upload response');
    }

    return UploadDataResponse.fromJson(decoded);
  }

  /// `POST {baseUrl}/retrain` — may run for a long time while the model trains.
  Future<RetrainResponse> retrainModel() async {
    final uri = Uri.parse('${AppConstants.baseUrl}/retrain');
    final response = await _client
        .post(uri)
        .timeout(const Duration(minutes: 20));

    if (response.statusCode != 200) {
      throw ApiException(
        _parseErrorBody(
          response.body,
          response.statusCode,
          fallback: 'Retrain failed',
        ),
      );
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw ApiException('Invalid retrain response');
    }

    return RetrainResponse.fromJson(decoded);
  }

  static String _parseErrorBody(
    String body,
    int statusCode, {
    required String fallback,
  }) {
    try {
      final dynamic decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail is String) return detail;
        if (detail is List) {
          return detail.map((e) {
            if (e is Map<String, dynamic>) {
              return e['msg']?.toString() ?? e.toString();
            }
            return e.toString();
          }).join(' ');
        }
      }
    } catch (_) {}
    return '$fallback (HTTP $statusCode)';
  }
}

/// Response from `POST /upload-data`.
class UploadDataResponse {
  const UploadDataResponse({
    required this.message,
    required this.label,
    required this.files,
  });

  final String message;
  final String label;
  final List<String> files;

  factory UploadDataResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['files'];
    final names = <String>[];
    if (raw is List) {
      for (final e in raw) {
        names.add(e?.toString() ?? '');
      }
    }
    return UploadDataResponse(
      message: json['message'] as String? ?? '',
      label: json['label'] as String? ?? '',
      files: names,
    );
  }
}

/// Response from `POST /retrain` (`retrain_model` return value).
class RetrainResponse {
  const RetrainResponse({
    required this.message,
    required this.validationAccuracy,
    required this.validationLoss,
  });

  final String message;
  final double validationAccuracy;
  final double validationLoss;

  factory RetrainResponse.fromJson(Map<String, dynamic> json) {
    final acc = _asDouble(json['validation_accuracy']);
    final loss = _asDouble(json['validation_loss']);
    return RetrainResponse(
      message: json['message'] as String? ?? '',
      validationAccuracy: acc,
      validationLoss: loss,
    );
  }
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
