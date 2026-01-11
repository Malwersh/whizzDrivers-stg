import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/environment.dart';

class ApiService {
  static String get baseUrl => Environment.apiBaseUrl;

  // Iraqi cities configuration
  static const Map<String, String> iraqiCities = {
    'baghdad': 'بغداد',
    'basra': 'البصرة',
    'erbil': 'أربيل',
    'mosul': 'الموصل',
    'najaf': 'النجف',
    'karbala': 'كربلاء',
  };

  static String? _currentCity;
  static String? _authToken;

  static void setCity(String cityCode) {
    _currentCity = cityCode;
  }

  static void setAuthToken(String token) {
    _authToken = token;
  }

  static String? get authToken => _authToken;

  static Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Accept-Language': 'ar-IQ,ar;q=0.9,en;q=0.8', // Iraqi Arabic preference
    };

    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }

    return headers;
  }

  static String get _cityEndpoint {
    if (_currentCity == null) {
      throw Exception('City not set. Please select your city first.');
    }
    return '$baseUrl/$_currentCity';
  } // Authentication

  static Future<Map<String, dynamic>> login({
    required String phoneNumber,
    required String otp,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/global/auth/login'),
      headers: _headers,
      body: jsonEncode({
        'phone_number': phoneNumber,
        'otp': otp,
        'country_code': '+964', // Iraq country code
      }),
    );

    return _handleResponse(response);
  } // Driver profile (deprecated)

  static Future<Map<String, dynamic>> getDriverProfile() async {
    throw Exception(
      'Legacy profile API deprecated. Use AWS /driver/me via AWSDynamoDBService.',
    );
  }

  // Orders management
  static Future<Map<String, dynamic>> getAvailableOrders() async {
    final response = await http.get(
      Uri.parse('$_cityEndpoint/orders/available'),
      headers: _headers,
    );

    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> acceptOrder(String orderId) async {
    final response = await http.post(
      Uri.parse('$_cityEndpoint/orders/$orderId/accept'),
      headers: _headers,
    );

    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> rejectOrder(
    String orderId, {
    String? reason,
  }) async {
    final response = await http.post(
      Uri.parse('$_cityEndpoint/orders/$orderId/reject'),
      headers: _headers,
      body: jsonEncode({
        'reason': reason ?? 'declined_by_driver',
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );

    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> acceptBatchedOrder(String batchId) async {
    final response = await http.post(
      Uri.parse('$_cityEndpoint/orders/batch/$batchId/accept'),
      headers: _headers,
    );

    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> rejectBatchedOrder(
    String batchId, {
    String? reason,
  }) async {
    final response = await http.post(
      Uri.parse('$_cityEndpoint/orders/batch/$batchId/reject'),
      headers: _headers,
      body: jsonEncode({
        'reason': reason ?? 'declined_by_driver',
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );

    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> updateOrderStatus({
    required String orderId,
    required String status,
    double? latitude,
    double? longitude,
  }) async {
    final Map<String, dynamic> body = {
      'status': status,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (latitude != null && longitude != null) {
      body['location'] = {'latitude': latitude, 'longitude': longitude};
    }

    final response = await http.put(
      Uri.parse('$_cityEndpoint/orders/$orderId/status'),
      headers: _headers,
      body: jsonEncode(body),
    );

    return _handleResponse(response);
  }

  // Earnings
  static Future<Map<String, dynamic>> getDailyEarnings(DateTime date) async {
    final dateStr = date.toIso8601String().split('T')[0];
    final response = await http.get(
      Uri.parse('$_cityEndpoint/driver/earnings/daily?date=$dateStr'),
      headers: _headers,
    );

    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> getWeeklyEarnings() async {
    final response = await http.get(
      Uri.parse('$_cityEndpoint/driver/earnings/weekly'),
      headers: _headers,
    );

    return _handleResponse(response);
  }

  // Location updates
  static Future<void> updateDriverLocation({
    required double latitude,
    required double longitude,
  }) async {
    final response = await http.post(
      Uri.parse('$_cityEndpoint/driver/location'),
      headers: _headers,
      body: jsonEncode({
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );

    _handleResponse(response);
  }

  // City-specific features
  static Future<Map<String, dynamic>> getCityInfo() async {
    final response = await http.get(
      Uri.parse('$_cityEndpoint/info'),
      headers: _headers,
    );

    return _handleResponse(response);
  }

  static Map<String, dynamic> _handleResponse(http.Response response) {
    final data = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'An error occurred');
    }
  }
}
