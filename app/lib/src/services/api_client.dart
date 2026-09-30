import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../utils/error_handler.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  String _customBaseUrl = ApiConstants.baseUrl;

  void setBaseUrl(String url) {
    _customBaseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  String get baseUrl => _customBaseUrl;

  Uri _buildUri(String path) {
    if (path.startsWith('http')) {
      return Uri.parse(path);
    }
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$_customBaseUrl$cleanPath');
  }

  Map<String, String> get _defaultHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Future<dynamic> get(String endpoint) async {
    try {
      final response = await http
          .get(_buildUri(endpoint), headers: _defaultHeaders)
          .timeout(ApiConstants.timeout);
      return _handleResponse(response);
    } catch (e) {
      throw AppError.fromException(e);
    }
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    try {
      final response = await http
          .post(
            _buildUri(endpoint),
            headers: _defaultHeaders,
            body: jsonEncode(body),
          )
          .timeout(ApiConstants.timeout);
      return _handleResponse(response);
    } catch (e) {
      throw AppError.fromException(e);
    }
  }

  Future<dynamic> delete(String endpoint) async {
    try {
      final response = await http
          .delete(_buildUri(endpoint), headers: _defaultHeaders)
          .timeout(ApiConstants.timeout);
      return _handleResponse(response);
    } catch (e) {
      throw AppError.fromException(e);
    }
  }

  Future<dynamic> uploadMultipart({
    required String endpoint,
    required File file,
    required String filename,
    Function(double progress)? onProgress,
  }) async {
    try {
      final uri = _buildUri(endpoint);
      final request = http.MultipartRequest('POST', uri);

      final multipartFile = await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: filename,
      );
      request.files.add(multipartFile);

      final streamedResponse = await request.send().timeout(const Duration(seconds: 45));
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response);
    } catch (e) {
      throw AppError.fromException(e);
    }
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      try {
        return jsonDecode(response.body);
      } catch (_) {
        return response.body;
      }
    } else {
      String errorMessage = 'Request failed with status ${response.statusCode}';
      String errorCode = 'HTTP_${response.statusCode}';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          errorMessage = decoded['message'] ?? decoded['error'] ?? errorMessage;
          errorCode = decoded['code'] ?? errorCode;
        }
      } catch (_) {}

      throw AppError(
        code: errorCode,
        message: errorMessage,
        statusCode: response.statusCode,
      );
    }
  }
}
