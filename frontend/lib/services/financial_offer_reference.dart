import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/environment.dart';
import '../providers/driver_auth_provider.dart';

class FinancialOfferReference {
  static const fields = ['financialPushVersion', 'orderId', 'offerId', 'waveNumber',
    'dispatchDriverId', 'driverId', 'cycleId', 'expiresAt', 'offerDigest'];
  static Map<String, dynamic> read(Map<String, dynamic> data) {
    final result = {for (final key in fields) key: data[key]};
    final id = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_:#.\-]{0,149}$');
    final wave = int.tryParse('${result['waveNumber']}');
    final expiry = DateTime.tryParse('${result['expiresAt']}');
    if ('${result['financialPushVersion']}' != '1' || wave == null || wave < 1 || wave > 1000 ||
        !['orderId','offerId','dispatchDriverId','driverId','cycleId'].every((key) => result[key] is String && id.hasMatch(result[key])) ||
        expiry == null || !expiry.isAfter(DateTime.now()) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch('${result['offerDigest']}')) {
      throw const FormatException('Invalid financial offer reference');
    }
    result['financialPushVersion'] = 1;
    result['waveNumber'] = wave;
    return result;
  }

  static Future<Map<String, dynamic>> hydrate(Map<String, dynamic> data, String owner,
      {http.Client? client, Future<String?> Function()? token}) async {
    final reference = read(data);
    if (reference['driverId'] != owner) throw const FormatException('Foreign offer');
    final readToken = token ?? DriverAuthHelper.getCurrentAccessToken;
    final credential = await readToken();
    if (credential == null || credential.isEmpty) { throw StateError('Authentication required'); }
    final transport = client ?? http.Client();
    try {
      final response = await transport.post(Uri.parse('${Environment.apiBaseUrl}/driver/financial-wave-offer'),
          headers: {'Authorization': 'Bearer $credential', 'Content-Type': 'application/json'},
          body: jsonEncode(reference)).timeout(const Duration(seconds: 10));
      if (await readToken() != credential || response.statusCode != 200) throw StateError('Offer unavailable');
      read(reference); // Expiry may pass while awaiting the server.
      final body = jsonDecode(response.body);
      final message = body is Map ? body['message'] : null;
      final offer = message is Map ? message['offer'] : null;
      if (body['success'] != true || message is! Map || message['type'] != 'financial_wave_offer' ||
          message['eventId'] != reference['offerId'] || offer is! Map ||
          offer['offerId'] != reference['offerId'] || offer['orderId'] != reference['orderId'] ||
          offer['waveNumber'] != reference['waveNumber'] || offer['expiresAt'] != reference['expiresAt'] ||
          offer['offerDigest'] != reference['offerDigest']) throw const FormatException('Changed financial offer');
      return Map<String, dynamic>.from(offer);
    } finally { if (client == null) transport.close(); }
  }
}
