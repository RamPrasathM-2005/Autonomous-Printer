import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/api_config.dart';
import '../models/print_server.dart';
import '../models/document.dart';
import '../models/order.dart';
import '../models/payment.dart';
import 'session_store.dart';
import 'api_error.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();
  Future<String>? _pendingSession;
  String get _baseUrl => ApiConfig.backendUrl;
  String get _sessionKey => 'customer-session:$_baseUrl';

  dynamic _decode(http.Response response) {
    final data = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      if (data['error'] == 'UNSUPPORTED_OPTIONS') {
        if (data['message'] == 'This printer does not support color.') {
          throw const ApiError('Color printing unavailable at this station.');
        }
        if (data['message'] == 'This printer does not support duplex.') {
          throw const ApiError(
            'Double-sided printing unavailable at this station.',
          );
        }
      }
      throw ApiError.fromCode(data['error'] as String?);
    }
    return data;
  }

  Future<String> _token() async {
    final saved = readSessionValue(_sessionKey);
    if (saved != null) {
      final value = jsonDecode(saved);
      if (DateTime.parse(value['expiresAt']).isAfter(DateTime.now())) {
        return value['token'];
      }
      clearSessionValue(_sessionKey);
      throw const ApiError('Session expired. Refresh to continue.');
    }
    _pendingSession ??= () async {
      final response = await http
          .post(Uri.parse('$_baseUrl/api/sessions'))
          .timeout(const Duration(seconds: 10));
      final data = _decode(response);
      writeSessionValue(_sessionKey, jsonEncode(data));
      return data['token'] as String;
    }();
    try {
      return await _pendingSession!;
    } finally {
      _pendingSession = null;
    }
  }

  Future<Map<String, String>> _headers() async => {
    'Authorization': 'Bearer ${await _token()}',
    'Content-Type': 'application/json',
  };

  Future<void> endSession() async {
    try {
      _decode(
        await http
            .delete(
              Uri.parse('$_baseUrl/api/sessions/current'),
              headers: await _headers(),
            )
            .timeout(const Duration(seconds: 10)),
      );
    } finally {
      clearSessionValue(_sessionKey);
      clearSessionValue('pending-order:$_baseUrl');
    }
  }

  bool get hasSession => readSessionValue(_sessionKey) != null;

  Future<bool> checkHealth() async {
    try {
      return (await http
                  .get(Uri.parse('$_baseUrl/health'))
                  .timeout(const Duration(seconds: 4)))
              .statusCode ==
          200;
    } catch (_) {
      return false;
    }
  }

  Future<String?> fetchActiveTunnelUrl() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/api/tunnel'))
          .timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['active'] == true && data['tunnel_url'] != null) {
          return data['tunnel_url'] as String;
        }
      }
    } catch (_) {}

    for (final candidate in ApiConfig.fallbackCandidates) {
      try {
        final res = await http
            .get(Uri.parse('$candidate/api/tunnel'))
            .timeout(const Duration(milliseconds: 1500));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['active'] == true && data['tunnel_url'] != null) {
            return data['tunnel_url'] as String;
          }
        }
      } catch (_) {}
    }
    return null;
  }

  Future<bool> probeAndSwitchWorkingBackend() async {
    if (await checkHealth()) return true;
    for (final candidate in ApiConfig.fallbackCandidates) {
      if (candidate == _baseUrl) continue;
      try {
        final res = await http
            .get(Uri.parse('$candidate/health'))
            .timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) {
          // If on mobile app, check if candidate exposes an active Cloudflare tunnel
          try {
            final tunnelRes = await http
                .get(Uri.parse('$candidate/api/tunnel'))
                .timeout(const Duration(seconds: 2));
            if (tunnelRes.statusCode == 200) {
              final tData = jsonDecode(tunnelRes.body);
              if (tData['active'] == true && tData['tunnel_url'] != null) {
                final tUrl = tData['tunnel_url'] as String;
                final tHealth = await http
                    .get(Uri.parse('$tUrl/health'))
                    .timeout(const Duration(seconds: 3));
                if (tHealth.statusCode == 200) {
                  await ApiConfig.updateBackendUrl(tUrl);
                  return true;
                }
              }
            }
          } catch (_) {}

          await ApiConfig.updateBackendUrl(candidate);
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  Future<List<PrintServer>> fetchPrintServers() async {
    final response = await http
        .get(Uri.parse('$_baseUrl/api/print-servers'))
        .timeout(const Duration(seconds: 8));
    return (_decode(response) as List)
        .map((j) => PrintServer.fromJson(j))
        .toList();
  }

  Future<PrintServer> getPrintServer(String id) async => PrintServer.fromJson(
    _decode(
      await http
          .get(Uri.parse('$_baseUrl/api/print-servers/$id'))
          .timeout(const Duration(seconds: 8)),
    ),
  );

  Future<UploadedDocument> uploadDocumentBytes({
    required List<int> bytes,
    required String filename,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/api/documents/upload'),
    );
    request.headers['Authorization'] = 'Bearer ${await _token()}';
    final extension = filename.split('.').last.toLowerCase();
    final mime = extension == 'png'
        ? 'image/png'
        : ['jpg', 'jpeg'].contains(extension)
        ? 'image/jpeg'
        : 'application/pdf';
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: MediaType.parse(mime),
      ),
    );
    final response = await http.Response.fromStream(
      await request.send().timeout(const Duration(seconds: 60)),
    );
    return UploadedDocument.fromJson(_decode(response));
  }

  Future<UploadedDocument> uploadDocument(File file) async =>
      uploadDocumentBytes(
        bytes: await file.readAsBytes(),
        filename: file.path.split(RegExp(r'[\\/]')).last,
      );

  Future<PrintOrder> createOrder({
    required String documentId,
    required String printServerId,
    required PrintSettings printSettings,
    List<Map<String, dynamic>>? items,
  }) async {
    final payload = {
      'documentId': documentId,
      'printServerId': printServerId,
      'settings': printSettings.toJson(),
      if (items != null && items.isNotEmpty) 'items': items,
    };
    final canonical = jsonEncode(payload);
    final saved = readSessionValue('pending-order:$_baseUrl');
    final previous = saved == null ? null : jsonDecode(saved);
    final key = previous != null && previous['payload'] == canonical
        ? previous['key'] as String
        : List.generate(
            24,
            (_) =>
                Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
          ).join();
    writeSessionValue(
      'pending-order:$_baseUrl',
      jsonEncode({'key': key, 'payload': canonical}),
    );
    final headers = await _headers();
    headers['Idempotency-Key'] = key;
    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/orders'),
          headers: headers,
          body: canonical,
        )
        .timeout(const Duration(seconds: 60));
    final createdOrder = PrintOrder.fromJson(_decode(response));
    return createdOrder;
  }

  Future<Map<String, dynamic>> checkActiveOrder({String? orderId}) async {
    final query = orderId != null && orderId.trim().isNotEmpty
        ? '?order_id=${Uri.encodeComponent(orderId.trim())}'
        : '';
    final uri = Uri.parse('$_baseUrl/api/orders/active$query');
    final response = await http
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 8));
    return Map<String, dynamic>.from(_decode(response));
  }

  Future<List<PrintOrder>> listOrders() async => (_decode(
    await http
        .get(Uri.parse('$_baseUrl/api/orders'), headers: await _headers())
        .timeout(const Duration(seconds: 10)),
  ) as List).map((j) => PrintOrder.fromJson(j)).toList();
  Future<PrintOrder> getOrder(String id) async => PrintOrder.fromJson(
    _decode(
      await http
          .get(Uri.parse('$_baseUrl/api/orders/$id'), headers: await _headers())
          .timeout(const Duration(seconds: 10)),
    ),
  );
  Future<OrderOtp> getOrderOtp(String id) async => OrderOtp.fromJson(
    _decode(
      await http
          .get(
            Uri.parse('$_baseUrl/api/orders/$id/otp'),
            headers: await _headers(),
          )
          .timeout(const Duration(seconds: 10)),
    ),
  );

  Future<Map<String, dynamic>> cancelOrder(String id, {String? reason}) async {
    final payload = {'reason': reason ?? 'Customer cancelled order'};
    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/orders/$id/cancel'),
          headers: await _headers(),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 15));
    return Map<String, dynamic>.from(_decode(response));
  }

  Future<PaymentInitiateResponse> createPaymentOrder(String id) =>
      createPayment(id);
  Future<Map<String, dynamic>> paymentCapabilities() async =>
      Map<String, dynamic>.from(
        _decode(
          await http
              .get(
                Uri.parse('$_baseUrl/api/payments/capabilities'),
                headers: await _headers(),
              )
              .timeout(const Duration(seconds: 10)),
        ),
      );

  Future<PaymentInitiateResponse> createPayment(String id) async =>
      PaymentInitiateResponse.fromJson(
        await _post('/api/payments/create', {'orderId': id}),
      );
  Future<bool> verifyPayment({
    required String orderId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final result = await _post('/api/payments/verify', {
      'orderId': orderId,
      'razorpayOrderId': razorpayOrderId,
      'razorpayPaymentId': razorpayPaymentId,
      'razorpaySignature': razorpaySignature,
    });
    return result['success'] == true;
  }

  Future<void> reconcilePayment(String id) async {
    await _post('/api/payments/reconcile', {'orderId': id});
  }

  Future<void> releaseOrder(String id, String otp) async {
    await _post('/api/orders/$id/release', {'otp': otp});
  }

  Future<bool> selectOrderPrinter({
    required String orderId,
    required String cupsPrinterName,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/orders/$orderId/printer');
      final response = await http
          .post(
            uri,
            headers: await _headers(),
            body: jsonEncode({'cups_printer_name': cupsPrinterName}),
          )
          .timeout(const Duration(seconds: 8));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<dynamic> _post(String path, Map<String, dynamic> data) async =>
      _decode(
        await http
            .post(
              Uri.parse('$_baseUrl$path'),
              headers: await _headers(),
              body: jsonEncode(data),
            )
            .timeout(const Duration(seconds: 35)),
      );
}
