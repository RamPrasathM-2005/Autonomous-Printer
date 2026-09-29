import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../config/api_config.dart';
import '../models/print_server.dart';
import '../models/document.dart';
import '../models/order.dart';
import '../models/payment.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String get _baseUrl => ApiConfig.backendUrl;

  // 1. Health check
  Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // 2. Print Servers
  Future<List<PrintServer>> fetchPrintServers() async {
    final response = await http
        .get(Uri.parse('$_baseUrl/api/print-servers'))
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => PrintServer.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load print servers: ${response.body}');
    }
  }

  Future<PrintServer> getPrintServer(String serverId) async {
    final response = await http
        .get(Uri.parse('$_baseUrl/api/print-servers/$serverId'))
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      return PrintServer.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load print server: ${response.body}');
    }
  }

  // 3. Document Upload (Universal: Web + Mobile + Desktop)
  Future<UploadedDocument> uploadDocumentBytes({
    required List<int> bytes,
    required String filename,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/documents/upload');
    final request = http.MultipartRequest('POST', uri);

    String extension = filename.split('.').last.toLowerCase();
    MediaType mediaType = MediaType('application', 'pdf');
    if (extension == 'jpg' || extension == 'jpeg') {
      mediaType = MediaType('image', 'jpeg');
    } else if (extension == 'png') {
      mediaType = MediaType('image', 'png');
    }

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: mediaType,
      ),
    );

    final streamedResponse =
        await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201 || response.statusCode == 200) {
      return UploadedDocument.fromJson(jsonDecode(response.body));
    } else {
      try {
        final errorData = jsonDecode(response.body);
        throw Exception(
            errorData['message'] ?? 'Upload failed (${response.statusCode})');
      } catch (_) {
        throw Exception('Upload failed: ${response.body}');
      }
    }
  }

  Future<UploadedDocument> uploadDocument(File file) async {
    final bytes = await file.readAsBytes();
    final filename = file.path.split(RegExp(r'[\\/]')).last;
    return uploadDocumentBytes(bytes: bytes, filename: filename);
  }

  // 4. Create Order & Validate Job
  Future<PrintOrder> createOrder({
    required String documentId,
    required String printServerId,
    required PrintSettings printSettings,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/orders');
    final payload = {
      'document_id': documentId,
      'print_server_id': printServerId,
      'print_settings': printSettings.toJson(),
    };

    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 201 || response.statusCode == 200) {
      return PrintOrder.fromJson(jsonDecode(response.body));
    } else {
      try {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Order creation failed');
      } catch (_) {
        throw Exception('Order creation failed: ${response.body}');
      }
    }
  }

  // 5. Fetch Orders
  Future<List<PrintOrder>> listOrders() async {
    final response = await http
        .get(Uri.parse('$_baseUrl/api/orders'))
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => PrintOrder.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load orders: ${response.body}');
    }
  }

  Future<PrintOrder> getOrder(String orderId) async {
    final response = await http
        .get(Uri.parse('$_baseUrl/api/orders/$orderId'))
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      return PrintOrder.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Order not found');
    }
  }

  // 6. Get OTP for Order
  Future<OrderOtp> getOrderOtp(String orderId) async {
    final response = await http
        .get(Uri.parse('$_baseUrl/api/orders/$orderId/otp'))
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      return OrderOtp.fromJson(jsonDecode(response.body));
    } else {
      try {
        final err = jsonDecode(response.body);
        throw Exception(err['message'] ?? 'OTP not ready');
      } catch (_) {
        throw Exception('Failed to get OTP: ${response.body}');
      }
    }
  }

  // 7. Payment Initiation
  Future<PaymentInitiateResponse> createPaymentOrder(String orderId) =>
      createPayment(orderId);

  Future<PaymentInitiateResponse> createPayment(String orderId) async {
    final uri = Uri.parse('$_baseUrl/api/payments/create');
    debugPrint('[FRONTEND API] >>> POST $uri - orderId: $orderId');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'orderId': orderId}),
        )
        .timeout(const Duration(seconds: 10));

    debugPrint('[FRONTEND API] <<< POST $uri - status: ${response.statusCode} - body: ${response.body}');

    if (response.statusCode == 201 || response.statusCode == 200) {
      final parsed = PaymentInitiateResponse.fromJson(jsonDecode(response.body));
      debugPrint('[FRONTEND API] Parsed PaymentInitiateResponse -> keyId: ${parsed.keyId}, razorpayOrderId: ${parsed.razorpayOrderId}');
      return parsed;
    } else {
      try {
        final err = jsonDecode(response.body);
        throw Exception(err['message'] ?? 'Failed to initialize payment');
      } catch (_) {
        throw Exception('Payment initialization failed: ${response.body}');
      }
    }
  }

  // 8. Payment Verification & Confirmation (Transitions order to WAITING_FOR_OTP and generates OTP)
  Future<bool> verifyPayment({
    required String orderId,
    String? razorpayOrderId,
    String? razorpayPaymentId,
    String? razorpaySignature,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/payments/verify');
    debugPrint('[FRONTEND API] >>> POST $uri - orderId: $orderId, rzpPaymentId: $razorpayPaymentId, rzpOrderId: $razorpayOrderId');
    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'orderId': orderId,
              'razorpayOrderId': razorpayOrderId,
              'razorpayPaymentId': razorpayPaymentId,
              'razorpaySignature': razorpaySignature,
            }),
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('[FRONTEND API] <<< POST $uri - status: ${response.statusCode} - body: ${response.body}');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('[FRONTEND API] !!! POST $uri exception: $e');
      return false;
    }
  }

  // 9. Payment Simulation & Webhook trigger
  // For local testing & seamless development, simulates successful Razorpay payment verification
  Future<bool> simulatePaymentVerification({
    required String orderId,
    required String razorpayOrderId,
    required double amount,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/payments/webhook');
      final payload = {
        'event': 'order.paid',
        'payload': {
          'order': {
            'entity': {
              'id': razorpayOrderId,
              'receipt': orderId,
              'amount': (amount * 100).toInt(),
              'currency': 'INR',
              'status': 'paid',
            }
          },
          'payment': {
            'entity': {
              'id': 'pay_${DateTime.now().millisecondsSinceEpoch}',
              'order_id': razorpayOrderId,
              'amount': (amount * 100).toInt(),
              'status': 'captured',
              'method': 'upi',
            }
          }
        }
      };

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Razorpay-Signature': 'dev_simulated_sig',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 8));

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }
}
