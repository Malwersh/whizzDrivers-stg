import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/environment.dart';
import 'driver_auth_helper.dart';

class MapActivityService {
  static Future<Map<String, dynamic>> load(List<String> ids) async {
    final driver = await DriverAuthHelper.getCurrentUserId(),
        token = await DriverAuthHelper.getCurrentAccessToken();
    if (driver == null || token == null)
      throw StateError('Authentication required');
    final items = <dynamic>[];
    DateTime? expiresAt;
    var enabled = true, isTestData = false;
    for (var i = 0; i < ids.length; i += 20) {
      final end = (i + 20 < ids.length) ? i + 20 : ids.length;
      final r = await http
          .post(Uri.parse('${Environment.apiBaseUrl}/driver/map-activity'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json'
              },
              body: jsonEncode({'storeIds': ids.sublist(i, end)}))
          .timeout(const Duration(seconds: 20));
      if (driver != await DriverAuthHelper.getCurrentUserId() ||
          token != await DriverAuthHelper.getCurrentAccessToken() ||
          r.statusCode != 200) throw StateError('Activity unavailable');
      final d = jsonDecode(utf8.decode(r.bodyBytes));
      if (d['success'] != true) throw StateError('Activity unavailable');
      items.addAll(d['items'] as List);
      enabled = d['enabled'] == true;
      isTestData = isTestData || d['isTestData'] == true;
      final at = DateTime.parse(d['generatedAt'] as String)
          .add(Duration(seconds: d['validForSeconds'] as int));
      if (expiresAt == null || at.isBefore(expiresAt)) expiresAt = at;
    }
    return {
      'items': items,
      'expiresAt': expiresAt?.toIso8601String(),
      'enabled': enabled,
      'isTestData': isTestData
    };
  }
}
