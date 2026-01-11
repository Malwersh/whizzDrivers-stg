import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/map_data.dart';
import '../providers/driver_auth_provider.dart';
import '../config/environment.dart';

/// Service for fetching map data from backend API
class MapDataService {
  static const String _baseUrl = Environment.apiBaseUrl;
  
  /// Fetch map data for driver's current location
  /// 
  /// Returns stores, regions, and hot stores info
  static Future<MapDataResponse> fetchMapData({
    required double lat,
    required double lng,
  }) async {
    try {
      // 🔐 Get authentication token
      final authToken = await DriverAuthHelper.getCurrentAccessToken();
      
      if (authToken == null) {
        throw Exception('Authentication required');
      }

      final uri = Uri.parse('$_baseUrl/driver/map-data').replace(
        queryParameters: {
          'lat': lat.toString(),
          'lng': lng.toString(),
        },
      );

      debugPrint('🗺️ Fetching map data: $uri');
      debugPrint('🔑 Auth token length: ${authToken.length}');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout - please check your connection');
        },
      );

      debugPrint('📥 Map data response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('✅ Map data received: ${data['nearby_stores']?.length ?? 0} stores');
        return MapDataResponse.fromJson(data);
      } else if (response.statusCode == 404) {
        debugPrint('❌ Region not found: ${response.body}');
        throw Exception('لا يمكن تحديد المنطقة من موقعك الحالي');
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        debugPrint('❌ Authentication failed: ${response.body}');
        throw Exception('فشل التحقق من الهوية - الرجاء تسجيل الدخول مجدداً');
      } else {
        debugPrint('❌ HTTP Error ${response.statusCode}: ${response.body}');
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      if (e.toString().contains('لا يمكن تحديد المنطقة')) {
        rethrow;
      }
      throw Exception('فشل تحميل بيانات الخريطة: $e');
    }
  }
}
