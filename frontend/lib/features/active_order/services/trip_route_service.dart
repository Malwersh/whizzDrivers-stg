import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/environment.dart';
import '../../../providers/driver_auth_provider.dart';

class TripRoadRoute {
  final List<List<double>> coordinates;
  final double distanceMeters, durationSeconds;
  TripRoadRoute(this.coordinates, this.distanceMeters, this.durationSeconds);
  factory TripRoadRoute.fromJson(Map<String, dynamic> value) {
    final points = (value['coordinates'] as List)
        .map((p) => (p as List).map((v) => (v as num).toDouble()).toList())
        .toList();
    if (value['purpose'] != 'DISPLAY_ONLY' ||
        points.length < 2 ||
        points.length > 20000 ||
        points.any((p) =>
            p.length != 2 ||
            p.any((n) => !n.isFinite) ||
            p[0].abs() > 180 ||
            p[1].abs() > 90)) throw const FormatException('Invalid road route');
    final distance = (value['distanceMeters'] as num).toDouble(),
        duration = (value['durationSeconds'] as num).toDouble();
    if (!distance.isFinite ||
        !duration.isFinite ||
        distance < 0 ||
        duration < 0) throw const FormatException('Invalid route metrics');
    return TripRoadRoute(points, distance, duration);
  }
}

class TripRouteService {
  TripRouteService({http.Client? client, Future<String?> Function()? token})
      : client = client ?? http.Client(),
        token = token ?? DriverAuthHelper.getCurrentAccessToken;
  final http.Client client;
  final Future<String?> Function() token;
  Future<TripRoadRoute> load(String orderId) async {
    final credential = await token();
    if (credential == null || credential.isEmpty)
      throw Exception('أعد تسجيل الدخول');
    final response = await client.get(
        Uri.parse(
            '${Environment.apiBaseUrl}/driver/orders/${Uri.encodeComponent(orderId)}/route'),
        headers: {
          'Authorization': 'Bearer $credential',
          'Accept': 'application/json'
        }).timeout(const Duration(seconds: 15));
    if (await token() != credential) throw Exception('تغيرت الجلسة');
    if (response.statusCode != 200) throw Exception('تعذر تحميل مسار الطريق');
    final data = jsonDecode(response.body);
    if (data['success'] != true || data['orderId'] != orderId)
      throw Exception('تغير الطلب');
    return TripRoadRoute.fromJson(Map<String, dynamic>.from(data['route']));
  }
}
