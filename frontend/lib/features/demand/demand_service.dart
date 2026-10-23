import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/environment.dart';
import '../../services/trips_service.dart';

class DemandService {
  DemandService(
      {http.Client? client, Future<Map<String, String>> Function()? headers})
      : client = client ?? http.Client(),
        headers = headers ?? TripsService.buildHeadersForProtectedRequest;
  final http.Client client;
  final Future<Map<String, String>> Function() headers;
  Future<Map<String, dynamic>> load() async {
    final auth = await headers();
    if (auth['Authorization'] == null)
      throw StateError('Authentication required');
    final response = await client
        .get(Uri.parse('${Environment.tripsApiBaseUrl}/driver/demand-forecast'),
            headers: auth)
        .timeout(const Duration(seconds: 20));
    if ((await headers())['Authorization'] != auth['Authorization'] ||
        response.statusCode != 200) throw StateError('Forecast unavailable');
    final data =
        Map<String, dynamic>.from(jsonDecode(utf8.decode(response.bodyBytes)));
    if (data['success'] != true || data['timezone'] != 'Asia/Baghdad')
      throw StateError('Forecast unavailable');
    return data;
  }

  void dispose() => client.close();
}
