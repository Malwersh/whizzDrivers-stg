import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/restaurant_data.dart';

class RestaurantService {
  static const String baseUrl = 'https://api.whizz.com'; // استبدل بالرابط الحقيقي
  
  // جلب المطاعم النشطة في المنطقة
  static Future<List<RestaurantData>> getActiveRestaurants({
    required double latitude,
    required double longitude,
    double radiusKm = 10.0,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/restaurants/active')
            .replace(queryParameters: {
          'lat': latitude.toString(),
          'lng': longitude.toString(),
          'radius': radiusKm.toString(),
        }),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer YOUR_API_TOKEN', // استبدل بالتوكن الحقيقي
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body)['restaurants'];
        return data.map((json) => RestaurantData.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load restaurants: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching restaurants: $e');
      // إرجاع بيانات تجريبية في حالة الخطأ
      return _getMockRestaurants(latitude, longitude);
    }
  }

  // بيانات تجريبية للاختبار (يمكن إزالتها لاحقاً)
  static List<RestaurantData> _getMockRestaurants(double lat, double lng) {
    return [
      RestaurantData(
        id: '1',
        name: 'مطعم الأصيل',
        address: 'شارع الملك فهد، الرياض',
        latitude: lat + 0.01,
        longitude: lng + 0.01,
        activeOrders: 18,
        isOnline: true,
        category: 'مأكولات عربية',
        rating: 4.5,
        imageUrl: 'https://example.com/restaurant1.jpg',
      ),
      RestaurantData(
        id: '2',
        name: 'بيتزا هت',
        address: 'حي النخيل، الرياض',
        latitude: lat - 0.015,
        longitude: lng + 0.02,
        activeOrders: 12,
        isOnline: true,
        category: 'بيتزا',
        rating: 4.2,
        imageUrl: 'https://example.com/restaurant2.jpg',
      ),
      RestaurantData(
        id: '3',
        name: 'مقهى ستاربكس',
        address: 'شارع العليا، الرياض',
        latitude: lat + 0.02,
        longitude: lng - 0.01,
        activeOrders: 6,
        isOnline: true,
        category: 'مشروبات',
        rating: 4.0,
        imageUrl: 'https://example.com/restaurant3.jpg',
      ),
      RestaurantData(
        id: '4',
        name: 'مطعم الدجاج المقلي',
        address: 'حي الملز، الرياض',
        latitude: lat - 0.01,
        longitude: lng - 0.015,
        activeOrders: 25,
        isOnline: true,
        category: 'دجاج',
        rating: 4.7,
        imageUrl: 'https://example.com/restaurant4.jpg',
      ),
      RestaurantData(
        id: '5',
        name: 'مطعم البحر الأبيض',
        address: 'شارع التحلية، الرياض',
        latitude: lat + 0.005,
        longitude: lng + 0.025,
        activeOrders: 3,
        isOnline: true,
        category: 'مأكولات بحرية',
        rating: 4.3,
        imageUrl: 'https://example.com/restaurant5.jpg',
      ),
      RestaurantData(
        id: '6',
        name: 'مطعم مغلق',
        address: 'حي الورود، الرياض',
        latitude: lat - 0.02,
        longitude: lng + 0.005,
        activeOrders: 0,
        isOnline: false,
        category: 'مأكولات سريعة',
        rating: 3.8,
        imageUrl: 'https://example.com/restaurant6.jpg',
      ),
    ];
  }

  // تحديث بيانات مطعم معين
  static Future<RestaurantData?> getRestaurantDetails(String restaurantId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/restaurants/$restaurantId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer YOUR_API_TOKEN',
        },
      );

      if (response.statusCode == 200) {
        return RestaurantData.fromJson(json.decode(response.body));
      }
    } catch (e) {
      print('Error fetching restaurant details: $e');
    }
    return null;
  }
}