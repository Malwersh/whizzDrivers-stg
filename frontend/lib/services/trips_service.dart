import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip_model.dart';
import '../config/environment.dart';

class TripsService {
  static const String baseUrl = Environment.tripsApiBaseUrl;
  
  /// Fetch trips for a driver
  /// Returns list of trips and pagination info
  static Future<Map<String, dynamic>> fetchDriverTrips({
    required String driverId,
    int limit = 20,
    String? nextToken,
  }) async {
    try {
      // Build query parameters
      final queryParams = {
        'limit': limit.toString(),
        if (nextToken != null) 'nextToken': nextToken,
      };
      
      final uri = Uri.parse('$baseUrl/driver/$driverId/trips')
          .replace(queryParameters: queryParams);
      
      print('📡 Fetching trips from: $uri');
      
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));
      
      print('📥 Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        
        if (jsonData['success'] == true) {
          final List<Trip> trips = (jsonData['trips'] as List)
              .map((tripJson) => Trip.fromJson(tripJson))
              .toList();
          
          print('✅ Fetched ${trips.length} trips');
          
          return {
            'success': true,
            'trips': trips,
            'count': jsonData['count'] ?? 0,
            'nextToken': jsonData['nextToken'],
            'hasMore': jsonData['hasMore'] ?? false,
          };
        } else {
          print('❌ API returned success: false');
          return {
            'success': false,
            'error': 'فشل في جلب الرحلات',
            'trips': <Trip>[],
          };
        }
      } else {
        print('❌ HTTP error: ${response.statusCode}');
        print('Response body: ${response.body}');
        return {
          'success': false,
          'error': 'خطأ في الاتصال بالخادم (${response.statusCode})',
          'trips': <Trip>[],
        };
      }
    } catch (e) {
      print('❌ Exception in fetchDriverTrips: $e');
      return {
        'success': false,
        'error': 'خطأ في الاتصال بالخادم: $e',
        'trips': <Trip>[],
      };
    }
  }
  
  /// Fetch trip statistics for a driver
  static Future<Map<String, dynamic>> fetchDriverStats({
    required String driverId,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/driver/$driverId/trips')
          .replace(queryParameters: {'action': 'stats'});
      
      print('📡 Fetching stats from: $uri');
      
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));
      
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
