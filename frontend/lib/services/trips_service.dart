import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip_model.dart';
import '../config/environment.dart';
import 'cognito_token_service.dart';

class TripsService {
  static const String baseUrl = Environment.tripsApiBaseUrl;

  static Future<Map<String, String>> buildHeadersForProtectedRequest() async {
    final prefs = await SharedPreferences.getInstance();
    final token = await CognitoTokenService.getAccessToken() ??
        prefs.getString('auth_token');
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> fetchDriverTrips(
      {String? driverId,
      int limit = 20,
      String? nextToken,
      String? status,
      DateTime? from,
      DateTime? to,
      http.Client? client}) async {
    try {
      final headers = await buildHeadersForProtectedRequest();
      if (headers['Authorization'] == null) throw Exception('AUTH_REQUIRED');
      final uri = Uri.parse('$baseUrl/driver/trips').replace(queryParameters: {
        'limit': '$limit',
        if (nextToken != null) 'nextToken': nextToken,
        if (status != null) 'status': status,
        if (from != null) 'from': from.toUtc().toIso8601String(),
        if (to != null) 'to': to.toUtc().toIso8601String()
      });
      final response = await (client == null
              ? http.get(uri, headers: headers)
              : client.get(uri, headers: headers))
          .timeout(const Duration(seconds: 30));
      if ((await buildHeadersForProtectedRequest())['Authorization'] !=
          headers['Authorization']) throw Exception('SESSION_CHANGED');
      if (response.statusCode != 200) throw Exception('HISTORY_UNAVAILABLE');
      final data = jsonDecode(response.body);
      if (data['success'] != true) throw Exception('HISTORY_UNAVAILABLE');
      return {
        'success': true,
        'trips': (data['trips'] as List)
            .map((v) => Trip.fromJson(Map<String, dynamic>.from(v)))
            .toList(),
        'nextToken': data['nextToken'],
        'hasMore': data['hasMore'] == true
      };
    } catch (_) {
      return {
        'success': false,
        'error': 'تعذر تحميل الرحلات. تحقق من الاتصال وأعد المحاولة.',
        'trips': <Trip>[]
      };
    }
  }

  static Future<Trip> fetchTrip(String orderId, {http.Client? client}) async {
    final headers = await buildHeadersForProtectedRequest();
    if (headers['Authorization'] == null) throw Exception('AUTH_REQUIRED');
    final uri =
        Uri.parse('$baseUrl/driver/trips/${Uri.encodeComponent(orderId)}');
    final response = await (client == null
            ? http.get(uri, headers: headers)
            : client.get(uri, headers: headers))
        .timeout(const Duration(seconds: 30));
    if ((await buildHeadersForProtectedRequest())['Authorization'] !=
            headers['Authorization'] ||
        response.statusCode != 200) throw Exception('TRIP_UNAVAILABLE');
    final data = jsonDecode(response.body);
    if (data['success'] != true || data['trip']?['orderId'] != orderId)
      throw Exception('TRIP_UNAVAILABLE');
    return Trip.fromJson(Map<String, dynamic>.from(data['trip']));
  }

  /// Fetch trip statistics for a driver
  static Future<Map<String, dynamic>> fetchDriverStats({
    required String driverId,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/driver/trips')
          .replace(queryParameters: {'action': 'stats'});

      print('📡 Fetching stats from: $uri');

      final response = await http
          .get(
            uri,
            headers: await buildHeadersForProtectedRequest(),
          )
          .timeout(const Duration(seconds: 30));

      print('📥 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData['success'] == true) {
          print('✅ Fetched stats');

          return {
            'success': true,
            'stats': jsonData['stats'],
          };
        } else {
          return {
            'success': false,
            'error': 'فشل في جلب الإحصائيات',
          };
        }
      } else {
        return {
          'success': false,
          'error': 'خطأ في الاتصال بالخادم (${response.statusCode})',
        };
      }
    } catch (e) {
      print('❌ Exception in fetchDriverStats: $e');
      return {
        'success': false,
        'error': 'خطأ في الاتصال بالخادم: $e',
      };
    }
  }

  /// Get current driver ID from SharedPreferences or Amplify
  static Future<String?> getCurrentDriverId() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Try 'driver_id' first (new format)
      String? driverId = prefs.getString('driver_id');
      if (driverId != null && driverId.isNotEmpty) {
        print('✅ Got driverId from SharedPreferences: $driverId');
        return driverId;
      }

      // Try 'driverId' (old format)
      driverId = prefs.getString('driverId');
      if (driverId != null && driverId.isNotEmpty) {
        print('✅ Got driverId from SharedPreferences (old key): $driverId');
        return driverId;
      }

      // Try to get from login_data
      final loginDataStr = prefs.getString('login_data');
      if (loginDataStr != null) {
        final loginData = json.decode(loginDataStr);
        driverId = loginData['driver_id'];
        if (driverId != null && driverId.isNotEmpty) {
          print('✅ Got driverId from login_data: $driverId');
          return driverId;
        }
      }

      print('❌ Driver ID not found in SharedPreferences');
      return null;
    } catch (e) {
      print('❌ Error getting driver ID: $e');
      return null;
    }
  }

  /// Group trips by date
  static Map<String, List<Trip>> groupTripsByDate(List<Trip> trips) {
    final Map<String, List<Trip>> grouped = {};

    for (final trip in trips) {
      final dateKey = trip.getFormattedDate();

      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }

      grouped[dateKey]!.add(trip);
    }

    return grouped;
  }
}
