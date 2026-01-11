import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AWSDynamoDBService {
  static final AWSDynamoDBService _instance = AWSDynamoDBService._internal();
  factory AWSDynamoDBService() => _instance;
  AWSDynamoDBService._internal();

  // Base URL for the new API Gateway HTTP API (set at runtime from config)
  static String?
  _baseUrl; // e.g., https://abc123.execute-api.us-east-1.amazonaws.com/<stage>
  static String? _authToken; // Cognito access token (Bearer)

  // Allow injecting a custom HTTP client for testing
  static http.Client _client = http.Client();
  static void setHttpClient(http.Client client) {
    _client = client;
  }

  static void configure({required String baseUrl, required String authToken}) {
    _baseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    _authToken = authToken;
  }

  Map<String, String> get _headers {
    final h = <String, String>{
      HttpHeaders.acceptHeader: 'application/json',
      HttpHeaders.contentTypeHeader: 'application/json',
    };
    if (_authToken != null && _authToken!.isNotEmpty) {
      h[HttpHeaders.authorizationHeader] = 'Bearer $_authToken';
    }
    return h;
  }

  Uri _uri(String path) {
    if (_baseUrl == null) {
      throw StateError(
        'AWSDynamoDBService not configured. Call configure(baseUrl, authToken).',
      );
    }
    return Uri.parse('$_baseUrl$path');
  }

  // Save driver registration data (PUT /driver/me)
  Future<bool> saveDriverRegistration({
    required String driverId,
    required String email,
    required String phoneNumber,
    required Map<String, String> attributes,
  }) async {
    try {
      debugPrint('DynamoDB API - Saving driver registration for: $driverId');
      final body = {
        'name': attributes['name'] ?? '',
        'city': attributes['city'] ?? '',
        'vehicleType': attributes['vehicleType'] ?? '',
        'licenseNumber': attributes['licenseNumber'] ?? '',
        'nationalId': attributes['nationalId'] ?? '',
        'docs': attributes['docs'] ?? '',
      };
      // Only include status if caller explicitly supplied (allows baseline PENDING_PROFILE to remain)
      final status = attributes['status'];
      if (status != null && status.isNotEmpty) {
        body['status'] = status;
      }

      final resp = await _client.put(
        _uri('/driver/me'),
        headers: _headers,
        body: jsonEncode(body),
      );
      debugPrint(
        'DynamoDB API - PUT /driver/me -> ${resp.statusCode}: ${resp.body}',
      );
      if (resp.statusCode >= 200 && resp.statusCode < 300) return true;
      return false;
    } catch (e) {
      debugPrint('DynamoDB API - Error saveDriverRegistration: $e');
      return false;
    }
  }

  // Get driver profile with retry/backoff for eventual consistency
  Future<Map<String, dynamic>?> getDriverProfile(
    String driverId, {
    int maxRetries = 5,
  }) async {
    int attempt = 0;
    Duration delay = const Duration(milliseconds: 300);
    while (true) {
      attempt += 1;
      try {
        debugPrint('DynamoDB API - GET /driver/me (attempt $attempt)');
        final resp = await _client.get(_uri('/driver/me'), headers: _headers);
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          return data['data'] as Map<String, dynamic>? ?? data;
        }
        if (resp.statusCode == 404) {
          debugPrint('DynamoDB API - Profile not found (404)');
        } else {
          debugPrint(
            'DynamoDB API - GET failed ${resp.statusCode}: ${resp.body}',
          );
        }
      } catch (e) {
        debugPrint('DynamoDB API - Error getDriverProfile: $e');
      }

      if (attempt >= maxRetries) return null;
      await Future.delayed(delay);
      delay *= 2; // exponential backoff
      if (delay > const Duration(seconds: 5)) {
        delay = const Duration(seconds: 5);
      }
    }
  }

  // Update driver verification/status (PUT /driver/me)
  Future<bool> updateDriverVerificationStatus({
    required String driverId,
    required bool isVerified,
  }) async {
    try {
      final status = isVerified ? 'VERIFIED' : 'PENDING_REVIEW';
      final resp = await _client.put(
        _uri('/driver/me'),
        headers: _headers,
        body: jsonEncode({'status': status}),
      );
      debugPrint(
        'DynamoDB API - update status -> ${resp.statusCode}: ${resp.body}',
      );
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (e) {
      debugPrint('DynamoDB API - Error updateDriverVerificationStatus: $e');
      return false;
    }
  }

  // Update driver profile fields (PUT /driver/me) without forcing status changes
  Future<bool> updateDriverProfile(Map<String, dynamic> fields) async {
    try {
      // Filter out null and empty values to avoid overwriting with blanks
      final body = <String, dynamic>{};
      for (final entry in fields.entries) {
        final v = entry.value;
        // Skip null values
        if (v == null) continue;
        // Skip empty strings
        if (v is String && v.isEmpty) continue;
        body[entry.key] = v;
      }
      if (body.isEmpty) return true; // nothing to update

      final jsonBody = jsonEncode(body);
      debugPrint('🌐 DynamoDB API - HTTP Request Details:');
      debugPrint('   URL: ${_uri('/driver/me')}');
      debugPrint('   Method: PUT');
      debugPrint('   Headers: $_headers');
      debugPrint('   Body (before encoding): $body');
      debugPrint('   Body (JSON): $jsonBody');
      debugPrint('   Body keys: ${body.keys.toList()}');
      debugPrint(
        '   Body has drivingLicenseUrl: ${body.containsKey('drivingLicenseUrl')}',
      );
      debugPrint(
        '   Body has registrationPaperUrl: ${body.containsKey('registrationPaperUrl')}',
      );

      final resp = await _client.put(
        _uri('/driver/me'),
        headers: _headers,
        body: jsonBody,
      );
      debugPrint(
        '📥 DynamoDB API - Response -> ${resp.statusCode}: ${resp.body}',
      );
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (e) {
      debugPrint('DynamoDB API - Error updateDriverProfile: $e');
      return false;
    }
  }

  Future<bool> saveOrderAssignment({
    required String orderId,
    required String driverId,
    required Map<String, dynamic> orderDetails,
  }) async {
    debugPrint('DynamoDB API - saveOrderAssignment stub');
    return true;
  }

  Future<Map<String, dynamic>?> getDriverEarnings(String driverId) async {
    debugPrint('DynamoDB API - getDriverEarnings stub');
    return null;
  }

  Future<bool> updateDriverStatus({
    required String driverId,
    required String status,
  }) async {
    debugPrint('DynamoDB API - updateDriverStatus stub');
    return true;
  }

  // Save driver registration with document files
  Future<bool> saveDriverRegistrationWithDocuments({
    required String driverId,
    required String email,
    required String phoneNumber,
    required Map<String, String> attributes,
    Map<String, dynamic>? documents,
    dynamic drivingLicenseFile,
    dynamic vehicleRegistrationFile,
    dynamic nonCriminalRecordFile,
  }) async {
    try {
      debugPrint('DynamoDB API - Saving driver registration with documents for: $driverId');
      
      final body = {
        'name': attributes['name'] ?? '',
        'city': attributes['city'] ?? '',
        'vehicleType': attributes['vehicleType'] ?? '',
        'licenseNumber': attributes['licenseNumber'] ?? '',
        'nationalId': attributes['nationalId'] ?? '',
        'docs': attributes['docs'] ?? '',
        'email': email,
        'phoneNumber': phoneNumber,
      };
      
      // Include status if provided
      final status = attributes['status'];
      if (status != null && status.isNotEmpty) {
        body['status'] = status;
      }
      
      // Include document references if provided (convert to JSON string)
      if (documents != null) {
        body['documents'] = jsonEncode(documents);
      }
      
      // Include individual document files if provided
      if (drivingLicenseFile != null) {
        body['drivingLicenseFile'] = drivingLicenseFile;
      }
      if (vehicleRegistrationFile != null) {
        body['vehicleRegistrationFile'] = vehicleRegistrationFile;
      }
      if (nonCriminalRecordFile != null) {
        body['nonCriminalRecordFile'] = nonCriminalRecordFile;
      }

      final resp = await _client.put(
        _uri('/driver/me'),
        headers: _headers,
        body: jsonEncode(body),
      );
      
      debugPrint('DynamoDB API - PUT /driver/me (with docs) -> ${resp.statusCode}: ${resp.body}');
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (e) {
      debugPrint('DynamoDB API - Error saveDriverRegistrationWithDocuments: $e');
      return false;
    }
  }

  // Save complete driver profile
  Future<bool> saveCompleteDriverProfile({
    required String driverId,
    required Map<String, dynamic> profileData,
  }) async {
    try {
      debugPrint('DynamoDB API - Saving complete driver profile for: $driverId');
      
      final resp = await _client.put(
        _uri('/driver/me'),
        headers: _headers,
        body: jsonEncode(profileData),
      );
      
      debugPrint('DynamoDB API - PUT /driver/me (complete profile) -> ${resp.statusCode}: ${resp.body}');
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (e) {
      debugPrint('DynamoDB API - Error saveCompleteDriverProfile: $e');
      return false;
    }
  }

  // Update driver availability status
  Future<bool> updateDriverAvailabilityStatus({
    required String driverId,
    required String status,
  }) async {
    try {
      debugPrint('DynamoDB API - Updating driver availability status: $status');
      
      final resp = await _client.patch(
        _uri('/driver/me/status'),
        headers: _headers,
        body: jsonEncode({'status': status}),
      );
      
      debugPrint('DynamoDB API - PATCH /driver/me/status -> ${resp.statusCode}: ${resp.body}');
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (e) {
      debugPrint('DynamoDB API - Error updateDriverAvailabilityStatus: $e');
      return false;
    }
  }

  // Query orders from WizzOrders table
  Future<Map<String, dynamic>?> queryOrders({
    List<String>? status,
    String? assignedDriverId,
    int? limit,
  }) async {
    try {
      debugPrint('DynamoDB API - Querying orders with status: $status');
      
      final queryParams = <String, String>{};
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status.join(',');
      }
      if (assignedDriverId != null) {
        queryParams['assignedDriverId'] = assignedDriverId;
      }
      if (limit != null) {
        queryParams['limit'] = limit.toString();
      }
      
      final uri = _uri('/orders').replace(queryParameters: queryParams);
      final resp = await _client.get(uri, headers: _headers);
      
      debugPrint('DynamoDB API - GET /orders -> ${resp.statusCode}');
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body);
      }
      return null;
    } catch (e) {
      debugPrint('DynamoDB API - Error queryOrders: $e');
      return null;
    }
  }

  // Update order status and details
  Future<bool> updateOrder({
    required String orderId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      debugPrint('DynamoDB API - Updating order: $orderId');
      
      final resp = await _client.patch(
        _uri('/orders/$orderId'),
        headers: _headers,
        body: jsonEncode(updates),
      );
      
      debugPrint('DynamoDB API - PATCH /orders/$orderId -> ${resp.statusCode}: ${resp.body}');
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (e) {
      debugPrint('DynamoDB API - Error updateOrder: $e');
      return false;
    }
  }

  // Add driver to rejected list for specific order
  Future<bool> addDriverToRejectedList({
    required String orderId,
    required String driverId,
  }) async {
    try {
      debugPrint('DynamoDB API - Adding driver $driverId to rejected list for order: $orderId');
      
      final resp = await _client.post(
        _uri('/orders/$orderId/reject'),
        headers: _headers,
        body: jsonEncode({'driverId': driverId}),
      );
      
      debugPrint('DynamoDB API - POST /orders/$orderId/reject -> ${resp.statusCode}');
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (e) {
      debugPrint('DynamoDB API - Error addDriverToRejectedList: $e');
      return false;
    }
  }

  // Update driver location
  Future<bool> updateDriverLocation({
    required String driverId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final resp = await _client.patch(
        _uri('/driver/me/location'),
        headers: _headers,
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
          'updatedAt': DateTime.now().toIso8601String(),
        }),
      );
      
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (e) {
      debugPrint('DynamoDB API - Error updateDriverLocation: $e');
      return false;
    }
  }

  // Get order details by ID
  Future<Map<String, dynamic>?> getOrderById(String orderId) async {
    try {
      debugPrint('DynamoDB API - Getting order by ID: $orderId');
      
      final resp = await _client.get(
        _uri('/orders/$orderId'),
        headers: _headers,
      );
      
      debugPrint('DynamoDB API - GET /orders/$orderId -> ${resp.statusCode}');
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body);
      }
      return null;
    } catch (e) {
      debugPrint('DynamoDB API - Error getOrderById: $e');
      return null;
    }
  }
}
