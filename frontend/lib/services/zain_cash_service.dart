import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';

class ZainCashService {
  // ZainCash API Configuration
  static const String _baseUrl = 'https://api.zaincash.iq';
  static const String _testBaseUrl = 'https://test.zaincash.iq';

  // Merchant Configuration (should be stored securely in production)
  static const String _merchantId = 'HADHIR_DRIVER_001';
  static const String _merchantSecret = 'YOUR_MERCHANT_SECRET_KEY';
  static const String _msisdn = '9647835077888'; // Merchant phone number

  // Production/Test mode flag
  static const bool _isProduction = false;

  static String get baseUrl => _isProduction ? _baseUrl : _testBaseUrl;

  /// Generate JWT token for ZainCash API authentication
  static String _generateJWTToken({
    required double amount,
    required String orderId,
    required String serviceType,
    String? redirectUrl,
  }) {
    final header = {'typ': 'JWT', 'alg': 'HS256'};

    final payload = {
      'iss': _merchantId,
      'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'exp':
          (DateTime.now().millisecondsSinceEpoch ~/ 1000) +
          3600, // 1 hour expiry
      'amount': amount.toInt(),
      'serviceType': serviceType,
      'msisdn': _msisdn,
      'orderId': orderId,
      'merchantId': _merchantId,
      'redirectUrl':
          redirectUrl ?? 'https://driver.hadhir.app/payment/callback',
      'lang': 'ar',
    };

    // Encode header and payload
    final encodedHeader = base64Url.encode(utf8.encode(jsonEncode(header)));
    final encodedPayload = base64Url.encode(utf8.encode(jsonEncode(payload)));

    // Create signature
    final signature = _generateSignature('$encodedHeader.$encodedPayload');

    return '$encodedHeader.$encodedPayload.$signature';
  }

  /// Generate HMAC-SHA256 signature for JWT
  static String _generateSignature(String data) {
    final key = utf8.encode(_merchantSecret);
    final bytes = utf8.encode(data);
    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(bytes);
    return base64Url.encode(digest.bytes);
  }

  /// Create a new ZainCash payment transaction
  static Future<ZainCashTransactionResult> createTransaction({
    required double amount,
    required String phoneNumber,
    String? orderId,
    String? description,
    String? redirectUrl,
  }) async {
    try {
      // Generate unique order ID if not provided
      orderId ??= _generateOrderId();

      // Validate amount (minimum 1000 IQD, maximum 1,000,000 IQD)
      if (amount < 1000 || amount > 1000000) {
        return ZainCashTransactionResult(
          success: false,
          error: 'المبلغ يجب أن يكون بين 1,000 و 1,000,000 دينار عراقي',
        );
      }

      // Generate JWT token
      final token = _generateJWTToken(
        amount: amount,
        orderId: orderId,
        serviceType: 'HadhirDriverWallet',
        redirectUrl: redirectUrl,
      );

      // Prepare request
      final response = await http.post(
        Uri.parse('$baseUrl/transaction/pay'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'token': token,
          'merchantId': _merchantId,
          'lang': 'ar',
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['IsSuccess'] == true) {
        return ZainCashTransactionResult(
          success: true,
          transactionId: responseData['Id'],
          paymentUrl: responseData['PaymentUrl'],
          orderId: orderId,
          amount: amount,
          message: 'تم إنشاء معاملة زين كاش بنجاح',
        );
      } else {
        return ZainCashTransactionResult(
          success: false,
          error: responseData['ErrorMessage'] ?? 'حدث خطأ في إنشاء المعاملة',
          errorCode: responseData['ErrorCode']?.toString(),
        );
      }
    } catch (e) {
      return ZainCashTransactionResult(
        success: false,
        error: 'فشل الاتصال بخدمة زين كاش: $e',
      );
    }
  }

  /// Check transaction status
  static Future<ZainCashStatusResult> checkTransactionStatus({
    required String transactionId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/transaction/get'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'Id': transactionId, 'MSISDN': _msisdn}),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['IsSuccess'] == true) {
        final status = _mapTransactionStatus(responseData['Status']);

        return ZainCashStatusResult(
          success: true,
          transactionId: transactionId,
          status: status,
          amount: responseData['Amount']?.toDouble(),
          orderId: responseData['OrderId'],
          timestamp: responseData['CreatedDate'] != null
              ? DateTime.parse(responseData['CreatedDate'])
              : null,
        );
      } else {
        return ZainCashStatusResult(
          success: false,
          error:
              responseData['ErrorMessage'] ?? 'فشل في التحقق من حالة المعاملة',
        );
      }
    } catch (e) {
      return ZainCashStatusResult(
        success: false,
        error: 'فشل في التحقق من حالة المعاملة: $e',
      );
    }
  }

  /// Handle callback from ZainCash
  static ZainCashCallbackResult handleCallback({
    required Map<String, dynamic> callbackData,
  }) {
    try {
      final token = callbackData['token'] as String?;
      final operation = callbackData['operation'] as String?;

      if (token == null || operation == null) {
        return ZainCashCallbackResult(
          success: false,
          error: 'بيانات الاستجابة غير صحيحة',
        );
      }

      // Decode JWT token to get transaction details
      if (JwtDecoder.isExpired(token)) {
        return ZainCashCallbackResult(
          success: false,
          error: 'انتهت صلاحية رمز المعاملة',
        );
      }

      final decodedToken = JwtDecoder.decode(token);
      final transactionId = decodedToken['transactionId']?.toString();
      final orderId = decodedToken['orderId']?.toString();
      final amount = decodedToken['amount']?.toDouble();

      final status = operation.toLowerCase() == 'success'
          ? ZainCashTransactionStatus.completed
          : ZainCashTransactionStatus.failed;

      return ZainCashCallbackResult(
        success: status == ZainCashTransactionStatus.completed,
        transactionId: transactionId,
        orderId: orderId,
        amount: amount,
        status: status,
        message: status == ZainCashTransactionStatus.completed
            ? 'تم إكمال الدفع بنجاح'
            : 'فشل في عملية الدفع',
      );
    } catch (e) {
      return ZainCashCallbackResult(
        success: false,
        error: 'خطأ في معالجة استجابة زين كاش: $e',
      );
    }
  }

  /// Generate unique order ID
  static String _generateOrderId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(9999);
    return 'HADHIR_${timestamp}_$random';
  }

  /// Map ZainCash status to our enum
  static ZainCashTransactionStatus _mapTransactionStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'success':
      case 'completed':
        return ZainCashTransactionStatus.completed;
      case 'pending':
      case 'processing':
        return ZainCashTransactionStatus.pending;
      case 'failed':
      case 'cancelled':
        return ZainCashTransactionStatus.failed;
      default:
        return ZainCashTransactionStatus.pending;
    }
  }

  /// Validate ZainCash phone number format
  static bool isValidZainCashNumber(String phoneNumber) {
    // ZainCash numbers in Iraq: 0780, 0781, 0782
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    // Check if it starts with country code
    if (cleanNumber.startsWith('964')) {
      final localNumber = cleanNumber.substring(3);
      return localNumber.startsWith('780') ||
          localNumber.startsWith('781') ||
          localNumber.startsWith('782');
    }

    // Check local format
    return cleanNumber.startsWith('0780') ||
        cleanNumber.startsWith('0781') ||
        cleanNumber.startsWith('0782');
  }

  /// Format phone number for ZainCash API
  static String formatPhoneNumber(String phoneNumber) {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    if (cleanNumber.startsWith('964')) {
      return cleanNumber;
    } else if (cleanNumber.startsWith('0')) {
      return '964${cleanNumber.substring(1)}';
    } else {
      return '964$cleanNumber';
    }
  }

  /// Calculate ZainCash processing fee
  static double calculateProcessingFee(double amount) {
    // ZainCash charges 500 IQD per transaction
    return 500.0;
  }

  /// Calculate total amount including fees
  static double calculateTotalAmount(double amount) {
    return amount + calculateProcessingFee(amount);
  }
}

/// Transaction creation result
class ZainCashTransactionResult {
  final bool success;
  final String? transactionId;
  final String? paymentUrl;
  final String? orderId;
  final double? amount;
  final String? message;
  final String? error;
  final String? errorCode;

  ZainCashTransactionResult({
    required this.success,
    this.transactionId,
    this.paymentUrl,
    this.orderId,
    this.amount,
    this.message,
    this.error,
    this.errorCode,
  });
}

/// Transaction status check result
class ZainCashStatusResult {
  final bool success;
  final String? transactionId;
  final ZainCashTransactionStatus? status;
  final double? amount;
  final String? orderId;
  final DateTime? timestamp;
  final String? error;

  ZainCashStatusResult({
    required this.success,
    this.transactionId,
    this.status,
    this.amount,
    this.orderId,
    this.timestamp,
    this.error,
  });
}

/// Callback handling result
class ZainCashCallbackResult {
  final bool success;
  final String? transactionId;
  final String? orderId;
  final double? amount;
  final ZainCashTransactionStatus? status;
  final String? message;
  final String? error;

  ZainCashCallbackResult({
    required this.success,
    this.transactionId,
    this.orderId,
    this.amount,
    this.status,
    this.message,
    this.error,
  });
}

/// Transaction status enumeration
enum ZainCashTransactionStatus { pending, completed, failed, cancelled }

/// Extension for status display
extension ZainCashTransactionStatusExtension on ZainCashTransactionStatus {
  String get displayName {
    switch (this) {
      case ZainCashTransactionStatus.pending:
        return 'في الانتظار';
      case ZainCashTransactionStatus.completed:
        return 'مكتملة';
      case ZainCashTransactionStatus.failed:
        return 'فاشلة';
      case ZainCashTransactionStatus.cancelled:
        return 'ملغاة';
    }
  }

  Color get statusColor {
    switch (this) {
      case ZainCashTransactionStatus.pending:
        return Colors.orange;
      case ZainCashTransactionStatus.completed:
        return Colors.green;
      case ZainCashTransactionStatus.failed:
      case ZainCashTransactionStatus.cancelled:
        return Colors.red;
    }
  }
}
