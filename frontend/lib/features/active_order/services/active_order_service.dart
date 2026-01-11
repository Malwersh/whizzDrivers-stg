import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/active_order_model.dart';
import '../../../providers/driver_auth_provider.dart';
import '../../../config/environment.dart';

/// Service للتعامل مع API الطلب النشط
class ActiveOrderService {
  static String get baseUrl => Environment.apiBaseUrl;

  Future<Map<String, String>> get _headers async {
    final authToken = await DriverAuthHelper.getCurrentAccessToken();
    
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (authToken != null && authToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }

    return headers;
  }

  /// التحقق من وجود طلب نشط (للاستدعاء عند فتح التطبيق)
  Future<bool> hasActiveOrder() async {
    try {
      final headers = await _headers;
      final response = await http.get(
        Uri.parse('$baseUrl/driver/active-order'),
        headers: headers,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('⏱️ hasActiveOrder timeout');
          throw Exception('Request timeout');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['hasActiveOrder'] == true;
      }

      return false;
    } catch (e) {
      print('❌ Error checking active order: $e');
      return false;
    }
  }

  /// جلب معلومات الطلب النشط
  Future<ActiveOrder?> getActiveOrder() async {
    try {
      print('🔍 ActiveOrderService: Fetching active order...');
      final headers = await _headers;
      print('🔑 Headers: $headers');
      
      final url = '$baseUrl/driver/active-order';
      print('📡 URL: $url');
      
      // ✅ Add timeout to prevent app crash
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('⏱️ Request timeout - no response from server');
          throw Exception('Request timeout');
        },
      );

      print('📥 getActiveOrder response status: ${response.statusCode}');
      print('📥 getActiveOrder response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // تحقق من نوع البيانات
        if (data is! Map<String, dynamic>) {
          print('⚠️ Invalid data format');
          return null;
        }

        if (data['hasActiveOrder'] == true && data['order'] != null) {
          print('✅ Active order found');
          return ActiveOrder.fromJson(data['order'] as Map<String, dynamic>);
        } else {
          print('ℹ️ No active order found');
        }
      } else if (response.statusCode == 404) {
        print('ℹ️ No active order (404)');
      } else {
        print('❌ Failed with status: ${response.statusCode}');
      }

      return null;
    } catch (e) {
      print('❌ Error fetching active order: $e');
      // لا نرمي Exception هنا لأن عدم وجود طلب نشط هو حالة طبيعية
      return null;
    }
  }

  /// جلب بيانات طلب معين بالـ ID
  Future<ActiveOrder> getOrderById(String orderId) async {
    try {
      print('🔍 ActiveOrderService: Fetching order by ID: $orderId');
      final headers = await _headers;
      print('🔑 Headers: $headers');
      
      final url = '$baseUrl/driver/orders/$orderId';
      print('📡 URL: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // تحقق من وجود بيانات الطلب
        if (data == null) {
          throw Exception('البيانات المستلمة فارغة');
        }
        
        // تحقق من نوع البيانات
        if (data is! Map<String, dynamic>) {
          throw Exception('تنسيق البيانات غير صحيح');
        }
        
        // البيانات قد تأتي إما:
        // 1. مباشرة: { orderId: "...", status: "..." }
        // 2. أو بـ wrapper: { order: { orderId: "...", status: "..." } }
        Map<String, dynamic> orderData;
        
        if (data.containsKey('order') && data['order'] != null) {
          // البيانات داخل wrapper
          orderData = data['order'] as Map<String, dynamic>;
          print('📦 Order data found in wrapper');
        } else if (data.containsKey('orderId')) {
          // البيانات مباشرة
          orderData = data;
          print('📦 Order data found directly');
        } else {
          throw Exception('الطلب غير موجود - تنسيق غير معروف');
        }
        
        return ActiveOrder.fromJson(orderData);
      } else if (response.statusCode == 404) {
        throw Exception('الطلب غير موجود أو انتهت صلاحيته');
      } else {
        try {
          final errorData = json.decode(response.body);
          final errorMessage = errorData['message'] ?? 'فشل في جلب بيانات الطلب';
          throw Exception(errorMessage);
        } catch (_) {
          throw Exception('فشل في جلب بيانات الطلب');
        }
      }
    } catch (e) {
      print('Error fetching order by ID: $e');
      if (e is Exception) {
        rethrow;
      }
      throw Exception('فشل في جلب بيانات الطلب: $e');
    }
  }

  /// تحديث حالة الطلب إلى "التوجه للمطعم" (عند النقر على زر "انطلق")
  Future<ActiveOrder> startHeadingToStore(String orderId) async {
    try {
      print('🚗 startHeadingToStore: Starting - OrderID: $orderId');
      final headers = await _headers;
      
      final url = '$baseUrl/driver/orders/$orderId/start-heading';
      print('🚗 startHeadingToStore: URL: $url');
      
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
      );

      print('🚗 startHeadingToStore: Response status: ${response.statusCode}');
      print('🚗 startHeadingToStore: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('🚗 startHeadingToStore: Success!');
        // البيانات موجودة مباشرة في الاستجابة، ليس داخل مفتاح 'order'
        return ActiveOrder.fromJson(data);
      } else {
        print('❌ startHeadingToStore: Failed with status ${response.statusCode}');
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'فشل في تحديث حالة بدء التوجه');
      }
    } catch (e) {
      print('❌ startHeadingToStore Error: $e');
      throw Exception('فشل في بدء التوجه للمطعم: $e');
    }
  }

  /// تحديث حالة الطلب إلى "وصلت للمطعم" (عند سحب السلايد)
  Future<ActiveOrder> arriveAtStore(String orderId) async {
    try {
      print('🏪 arriveAtStore: Starting - OrderID: $orderId');
      final headers = await _headers;
      print('🏪 arriveAtStore: Headers ready');
      
      final url = '$baseUrl/driver/orders/$orderId/arrive-store';
      print('🏪 arriveAtStore: URL: $url');
      
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
      );

      print('🏪 arriveAtStore: Response status: ${response.statusCode}');
      print('🏪 arriveAtStore: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('🏪 arriveAtStore: Success! Parsing order data...');
        return ActiveOrder.fromJson(data);
      } else {
        print('❌ arriveAtStore: Failed with status ${response.statusCode}');
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'فشل في تحديث حالة الوصول للمطعم');
      }
    } catch (e) {
      print('❌ arriveAtStore Error: $e');
      throw Exception('فشل في تسجيل الوصول للمطعم: $e');
    }
  }

  /// تحديث حالة الطلب إلى "تم الاستلام"
  Future<ActiveOrder> pickupOrder(String orderId) async {
    try {
      final headers = await _headers;
      final response = await http.post(
        Uri.parse('$baseUrl/driver/orders/$orderId/pickup'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ActiveOrder.fromJson(data);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'فشل في تحديث الحالة');
      }
    } catch (e) {
      print('Error picking up order: $e');
      throw Exception('فشل في تسجيل استلام الطلب: $e');
    }
  }

  /// تحديث حالة الطلب إلى "متوجه للعميل" (بعد استلام الطلب من المطعم)
  Future<ActiveOrder> startHeadingToCustomer(String orderId) async {
    print('🚗 startHeadingToCustomer: Starting - OrderID: $orderId');
    try {
      final headers = await _headers;
      final url = '$baseUrl/driver/orders/$orderId/start-heading-to-customer';
      print('🚗 startHeadingToCustomer: URL: $url');

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
      );

      print('🚗 startHeadingToCustomer: Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('🚗 startHeadingToCustomer: Success');
        return ActiveOrder.fromJson(data);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'فشل في تحديث حالة التوجه للعميل');
      }
    } catch (e) {
      print('❌ Error starting heading to customer: $e');
      throw Exception('فشل في تحديث حالة بدء التوجه للعميل: $e');
    }
  }

  /// تحديث حالة الطلب إلى "وصلت للعميل"
  Future<ActiveOrder> arriveAtCustomer(String orderId) async {
    try {
      final headers = await _headers;
      final response = await http.post(
        Uri.parse('$baseUrl/driver/orders/$orderId/arrive-customer'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ActiveOrder.fromJson(data);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'فشل في تحديث الحالة');
      }
    } catch (e) {
      print('Error arriving at customer: $e');
      throw Exception('فشل في تسجيل الوصول للعميل: $e');
    }
  }

  /// تحديث حالة الطلب إلى "تم التسليم"
  Future<Map<String, dynamic>> deliverOrder(
    String orderId, {
    double? cashCollected,
    String? deliveryNotes,
  }) async {
    try {
      final body = <String, dynamic>{};
      
      // إذا تم تمرير cashCollected (المبلغ)، نرسل:
      // 1. cashCollected: true (تأكيد الاستلام)
      // 2. cashAmount: المبلغ الفعلي
      if (cashCollected != null && cashCollected > 0) {
        body['cashCollected'] = true;
        body['cashAmount'] = cashCollected;
      } else {
        body['cashCollected'] = false;
      }
      
      if (deliveryNotes != null) {
        body['deliveryNotes'] = deliveryNotes;
      }

      final headers = await _headers;
      final response = await http.post(
        Uri.parse('$baseUrl/driver/orders/$orderId/deliver'),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // الاستجابة لا تحتوي على بيانات الطلب كاملة، فقط رسالة النجاح
        return {
          'success': data['success'] ?? true,
          'message': data['message'] ?? 'تم تسليم الطلب بنجاح',
          'orderId': data['orderId'],
          'deliveredAt': data['deliveredAt'],
          'holdCaptured': data['holdCaptured'] ?? false,
          'capturedAmount': data['capturedAmount'] ?? 0,
        };
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'فشل في تحديث الحالة');
      }
    } catch (e) {
      print('Error delivering order: $e');
      throw Exception('فشل في تسجيل تسليم الطلب: $e');
    }
  }

  /// الإبلاغ عن مشكلة في المطعم
  Future<Map<String, dynamic>> reportStoreIssue(
    String orderId, {
    required String issueType,
    String? notes,
  }) async {
    try {
      final headers = await _headers;
      final response = await http.post(
        Uri.parse('$baseUrl/driver/orders/$orderId/issue'),
        headers: headers,
        body: json.encode({
          'issueType': issueType,
          'issueSource': 'Store',
          'notes': notes,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'فشل في إرسال البلاغ');
      }
    } catch (e) {
      print('Error reporting store issue: $e');
      throw Exception('فشل في الإبلاغ عن المشكلة: $e');
    }
  }

  /// الإبلاغ عن عدم توفر العميل
  Future<Map<String, dynamic>> reportCustomerUnreachable(
      String orderId) async {
    try {
      final headers = await _headers;
      final response = await http.post(
        Uri.parse('$baseUrl/driver/orders/$orderId/customer-unreachable'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'فشل في إرسال البلاغ');
      }
    } catch (e) {
      print('Error reporting customer unreachable: $e');
      throw Exception('فشل في الإبلاغ عن عدم توفر العميل: $e');
    }
  }

  /// إلغاء الطلب من قبل السائق
  Future<Map<String, dynamic>> cancelOrderByDriver(
    String orderId, {
    required String reason,
    String? notes,
  }) async {
    try {
      final headers = await _headers;
      final response = await http.post(
        Uri.parse('$baseUrl/driver/orders/$orderId/cancel-by-driver'),
        headers: headers,
        body: json.encode({
          'reason': reason,
          'notes': notes,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'فشل في إلغاء الطلب');
      }
    } catch (e) {
      print('Error canceling order: $e');
      throw Exception('فشل في إلغاء الطلب: $e');
    }
  }

  /// تحديث موقع السائق
  Future<void> updateDriverLocation({
    required String driverId,
    required String orderId,
    required double lat,
    required double lng,
  }) async {
    try {
      final headers = await _headers;
      await http.post(
        Uri.parse('$baseUrl/driver/location'),
        headers: headers,
        body: json.encode({
          'driverId': driverId,
          'orderId': orderId,
          'lat': lat,
          'lng': lng,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
    } catch (e) {
      print('Error updating driver location: $e');
      // لا نرمي Exception هنا لأن تحديث الموقع ليس حرجاً
    }
  }
}
