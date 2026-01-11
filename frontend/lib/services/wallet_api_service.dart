import 'dart:convert';
import 'package:http/http.dart' as http;import 'package:uuid/uuid.dart';import '../models/wallet_balance.dart';
import '../models/transaction_history.dart';
import '../services/driver_auth_helper.dart';
import '../config/environment.dart';

/// Wallet API Service
/// 
/// Handles all HTTP communication with the Wallet Service backend.
/// Uses JWT token from DriverAuthHelper for authentication.
class WalletApiService {
  // Backend API URL
  static const String baseUrl = Environment.walletApiBaseUrl;

  /// Get current driver's wallet balance
  /// 
  /// Endpoint: GET /wallet/me
  /// Returns: WalletBalance with available, locked, and total balance
  /// Throws: WalletNotFoundException if wallet doesn't exist
  /// Throws: UnauthorizedException if token is invalid
  Future<WalletBalance> getWalletBalance() async {
    final token = await DriverAuthHelper.getCurrentAccessToken();
    if (token == null) {
      throw UnauthorizedException('Not authenticated - please login');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/wallet/me'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return WalletBalance.fromJson(data);
    } else if (response.statusCode == 404) {
      throw WalletNotFoundException('Wallet not found for this driver');
    } else if (response.statusCode == 401) {
      throw UnauthorizedException('Token expired or invalid - please login again');
    } else {
      throw WalletApiException(
        'Failed to load wallet: ${response.statusCode}',
        response.statusCode,
        response.body,
      );
    }
  }

  /// Get transaction history for current driver
  /// 
  /// Endpoint: GET /wallet/me/transactions
  /// Parameters:
  ///   - limit: Number of transactions to fetch (default: 20)
  ///   - nextToken: Pagination token for next page (optional)
  /// Returns: TransactionHistory with list of transactions
  Future<TransactionHistory> getTransactionHistory({
    int limit = 20,
    String? nextToken,
  }) async {
    final token = await DriverAuthHelper.getCurrentAccessToken();
    if (token == null) {
      throw UnauthorizedException('Not authenticated - please login');
    }

    final queryParams = <String, String>{
      'limit': limit.toString(),
      if (nextToken != null && nextToken.isNotEmpty) 'nextToken': nextToken,
    };

    final uri = Uri.parse('$baseUrl/wallet/me/transactions')
        .replace(queryParameters: queryParams);

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return TransactionHistory.fromJson(data);
    } else if (response.statusCode == 401) {
      throw UnauthorizedException('Token expired or invalid - please login again');
    } else {
      throw WalletApiException(
        'Failed to load transactions: ${response.statusCode}',
        response.statusCode,
        response.body,
      );
    }
  }

  /// Request a topup (Phase 2)
  /// 
  /// Endpoint: POST /wallet/topup/request
  /// Parameters:
  ///   - amount: Amount to topup in IQD
  ///   - method: CASH_AGENT or MANUAL_VERIFICATION
  ///   - evidenceRef: URL to evidence (for MANUAL_VERIFICATION)
  ///   - note: Optional note
  /// Returns: Map with topup request details
  /// Security: Uses idempotency key to prevent duplicate requests
  Future<Map<String, dynamic>> requestTopup({
    required int amount,
    required String method,
    String? evidenceRef,
    String? note,
  }) async {
    final token = await DriverAuthHelper.getCurrentAccessToken();
    if (token == null) {
      throw UnauthorizedException('Not authenticated - please login');
    }

    // Generate idempotency key to prevent duplicate submissions
    final idempotencyKey = const Uuid().v4();

    final response = await http.post(
      Uri.parse('$baseUrl/wallet/topup/request'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'X-Idempotency-Key': idempotencyKey, // Security: Prevent duplicate requests
      },
      body: json.encode({
        'amount': amount,
        'method': method,
        if (evidenceRef != null) 'evidenceRef': evidenceRef,
        if (note != null) 'note': note,
        'idempotencyKey': idempotencyKey, // Also in body for backend tracking
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 401) {
      throw UnauthorizedException('Token expired or invalid - please login again');
    } else if (response.statusCode == 400) {
      final errorData = json.decode(response.body);
      throw WalletApiException(
        errorData['message'] ?? 'Invalid request',
        response.statusCode,
        response.body,
      );
    } else {
      throw WalletApiException(
        'Failed to request topup: ${response.statusCode}',
        response.statusCode,
        response.body,
      );
    }
  }

  /// Get list of topup requests for current driver (Phase 2)
  /// 
  /// Endpoint: GET /wallet/me/topups
  /// Parameters:
  ///   - limit: Number of requests to fetch (default: 20)
  ///   - status: Filter by status (optional)
  /// Returns: List of topup requests
  Future<List<Map<String, dynamic>>> getTopupRequests({
    int limit = 20,
    String? status,
  }) async {
    final token = await DriverAuthHelper.getCurrentAccessToken();
    if (token == null) {
      throw UnauthorizedException('Not authenticated - please login');
    }

    final queryParams = <String, String>{
      'limit': limit.toString(),
      if (status != null && status.isNotEmpty) 'status': status,
    };

    final uri = Uri.parse('$baseUrl/wallet/me/topups')
        .replace(queryParameters: queryParams);

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['topups'] ?? []);
    } else if (response.statusCode == 401) {
      throw UnauthorizedException('Token expired or invalid - please login again');
    } else {
      throw WalletApiException(
        'Failed to load topup requests: ${response.statusCode}',
        response.statusCode,
        response.body,
      );
    }
  }
}

// ============================================================================
// Custom Exceptions
// ============================================================================

/// Base exception for wallet API errors
class WalletApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? responseBody;

  WalletApiException(this.message, [this.statusCode, this.responseBody]);

  @override
  String toString() {
    if (statusCode != null) {
      return 'WalletApiException: $message (Status: $statusCode)';
    }
    return 'WalletApiException: $message';
  }
}

/// Exception thrown when wallet is not found (404)
class WalletNotFoundException implements Exception {
  final String message;

  WalletNotFoundException(this.message);

  @override
  String toString() => 'WalletNotFoundException: $message';
}

/// Exception thrown when authentication fails (401)
class UnauthorizedException implements Exception {
  final String message;

  UnauthorizedException(this.message);

  @override
  String toString() => 'UnauthorizedException: $message';
}

/// Exception thrown when network request fails
class NetworkException implements Exception {
  final String message;

  NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}
