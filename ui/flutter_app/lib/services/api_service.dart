import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/constants.dart';

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
    final conf = json['confidence'];
    double c = 0;
    if (conf is num) {
      c = conf.toDouble();
    }
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
    final acc = json['validation_accuracy'];
    final loss = json['validation_loss'];
    return RetrainResponse(
      message: json['message'] as String? ?? '',
      validationAccuracy: acc is num ? acc.toDouble() : 0,
      validationLoss: loss is num ? loss.toDouble() : 0,
    );
  }
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
