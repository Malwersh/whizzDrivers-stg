import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../config/environment.dart';
import '../providers/driver_auth_provider.dart';

/// ✨ Driver Search API Service
/// Handles start/stop searching via REST API
class DriverSearchApiService {
  // API Gateway base URL for driver profile API
  static String get _baseUrl => Environment.apiBaseUrl;
  
  /// Start searching for orders
  /// 
  /// This API call:
  /// - Checks driver status (ACTIVE/BANNED/SUSPENDED)
  /// - Determines current region from GPS coordinates
  /// - Verifies WebSocket connection exists
  /// - Updates WizzDriverLiveState with all 18+ fields
  /// - Returns region information and confirmation
  static Future<Map<String, dynamic>> startSearching({
    required double latitude,
    required longitude,
    Map<String, dynamic>? deviceInfo,
  }) async {
    try {
      // Get auth token
      final authToken = await DriverAuthHelper.getCurrentAccessToken();
      
      if (authToken == null) {
        throw Exception('Authentication required');
      }
      
      // Prepare request body
      final body = {
        'lat': latitude,
        'lng': longitude,
        if (deviceInfo != null) 'deviceInfo': deviceInfo,
      };
      
      print('📡 Sending start-searching request: $body');
      
      // Make API call
      final response = await http.post(
        Uri.parse('$_baseUrl/driver/start-searching'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode(body),
      );
      
      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');
      
      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'فشل في بدء البحث',
          'error': data,
        };
      }
    } catch (e) {
      print('❌ Error in startSearching: $e');
      return {
        'success': false,
        'message': 'خطأ في الاتصال: $e',
      };
    }
  }
  
  /// Stop searching for orders
  /// 
  /// This API call:
  /// - Updates WizzDriverLiveState: isSearching=false, status='offline'
  /// - Keeps WebSocket connection active
  /// - Returns confirmation
  static Future<Map<String, dynamic>> stopSearching() async {
    try {
      // Get auth token
      final authToken = await DriverAuthHelper.getCurrentAccessToken();
      
      if (authToken == null) {
        throw Exception('Authentication required');
      }
      
      print('📡 Sending stop-searching request');
      
      // Make API call
      final response = await http.post(
        Uri.parse('$_baseUrl/driver/stop-searching'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({}),
      );
      
      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');
      
      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'فشل في إيقاف البحث',
          'error': data,
        };
      }
    } catch (e) {
      print('❌ Error in stopSearching: $e');
      return {
        'success': false,
        'message': 'خطأ في الاتصال: $e',
      };
    }
  }
  
  /// 🆕 Accept wave offer
  /// 
  /// This API call:
  /// - Sends acceptance to API Gateway
  /// - Handles race conditions (offer already taken)
  /// - Returns success/failure with order details
  static Future<Map<String, dynamic>> acceptWaveOffer({
    required String offerId,
    required String driverId,
  }) async {
    try {
      // Get auth token
      final authToken = await DriverAuthHelper.getCurrentAccessToken();
      
      if (authToken == null) {
        throw Exception('Authentication required');
      }
      
      // Prepare request body
      // Extract orderId from offerId (format: OFFER_{orderId}_{driverId}_W{waveNumber})
      String? orderId;
      if (offerId.startsWith('OFFER_')) {
        final parts = offerId.split('_');
        if (parts.length >= 3) {
          orderId = parts[1]; // Second part is orderId
        }
      }
      
      final body = {
        'offerId': offerId,
        'driverId': driverId,
        if (orderId != null) 'orderId': orderId,
      };
      
      print('🌊 Sending accept-wave-offer request:');
      print('   - offerId: $offerId');
      print('   - driverId: $driverId');
      print('   - orderId: $orderId');
      print('   - body: $body');
      
      // Make API call to API Gateway (CORRECT ENDPOINT)
      final response = await http.post(
        Uri.parse('$_baseUrl/driver/accept-wave-offer'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode(body),
      );
      
      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');
      
      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'data': data,
          'message': data['message'] ?? 'تم قبول الطلب بنجاح',
        };
      } else {
        // Handle specific error cases
        String errorMessage = data['message'] ?? 'فشل في قبول العرض';
        
        if (errorMessage.contains('already accepted') || 
            errorMessage.contains('تم قبوله من قبل')) {
          errorMessage = 'عذراً، تم قبول هذا الطلب من سائق آخر';
        } else if (errorMessage.contains('expired') || 
                   errorMessage.contains('منتهي')) {
          errorMessage = 'انتهى وقت هذا العرض';
        }
        
        return {
          'success': false,
          'message': errorMessage,
          'error': data,
        };
      }
    } catch (e) {
      print('❌ Error in acceptWaveOffer: $e');
      return {
        'success': false,
        'message': 'خطأ في الاتصال: $e',
      };
    }
  }
  
  /// 🆕 Reject Wave Offer
  static Future<Map<String, dynamic>> rejectWaveOffer({
    required String offerId,
    required String driverId,
    String? reason,
  }) async {
    try {
      // Get auth token
      final authToken = await DriverAuthHelper.getCurrentAccessToken();
      
      if (authToken == null) {
        throw Exception('Authentication required');
      }
      
      // Extract orderId from offerId (format: OFFER_{orderId}_{driverId}_W{waveNumber})
      String? orderId;
      if (offerId.startsWith('OFFER_')) {
        final parts = offerId.split('_');
        if (parts.length >= 3) {
          orderId = parts[1]; // Second part is orderId
        }
      }
      
      // Prepare request body
      final body = {
        'offerId': offerId,
        'driverId': driverId,
        if (orderId != null) 'orderId': orderId,
        'reason': reason ?? 'driver_declined',
      };
      
      print('❌ Sending reject-wave-offer request: $body');
      
      // Make API call to API Gateway (SAME AS ACCEPT - DriverAPI_v2)
      final response = await http.post(
        Uri.parse('$_baseUrl/driver/reject-wave-offer'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode(body),
      );
      
      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');
      
      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'data': data,
          'message': data['message'] ?? 'تم رفض الطلب',
        };
      } else {
        String errorMessage = data['message'] ?? 'فشل في رفض العرض';
        
        return {
          'success': false,
          'message': errorMessage,
          'error': data,
        };
      }
    } catch (e) {
      print('❌ Error in rejectWaveOffer: $e');
      return {
        'success': false,
        'message': 'خطأ في الاتصال: $e',
      };
    }
  }
  
  /// Get current GPS position with proper permissions handling
  static Future<Position?> getCurrentPosition() async {
    try {
      if (Environment.useTestLocation) {
        final position = Position(
          latitude: Environment.testLatitude,
          longitude: Environment.testLongitude,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
        print('🧪 Test position: ${position.latitude}, ${position.longitude}');
        return position;
      }
      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('❌ Location permission denied');
          return null;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        print('❌ Location permission denied forever');
        return null;
      }
      
      // Get position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      print('📍 Current position: ${position.latitude}, ${position.longitude}');
      return position;
      
    } catch (e) {
      print('❌ Error getting position: $e');
      return null;
    }
  }
  
  /// 📊 Get driver performance metrics
  /// Returns acceptance rate, response rate, and other stats
  static Future<Map<String, dynamic>?> getDriverMetrics() async {
    try {
      // Get auth token
      final authToken = await DriverAuthHelper.getCurrentAccessToken();
      
      if (authToken == null) {
        throw Exception('Authentication required');
      }
      
      print('📡 Fetching driver metrics...');
      
      // Make API call
      final response = await http.get(
        Uri.parse('$_baseUrl/driver/metrics'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      );
      
      print('📥 Metrics response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Metrics fetched: $data');
        return data;
      } else {
        print('❌ Failed to fetch metrics: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Error fetching driver metrics: $e');
      return null;
    }
  }
}
