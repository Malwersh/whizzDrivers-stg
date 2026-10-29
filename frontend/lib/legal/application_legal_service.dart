import 'dart:convert';
import 'package:http/http.dart' as http;
import 'application_legal_bundle.dart';

class ApplicationLegalService {
  static final instance = ApplicationLegalService();
  final http.Client _client;
  final String baseUrl;
  final String audience;
  ApplicationLegalBundle? _cached;
  DateTime? _loadedAt;
  ApplicationLegalService({
    http.Client? client,
    this.baseUrl = const String.fromEnvironment('LEGAL_API_BASE_URL',
        defaultValue:
            'https://f44z33oz55.execute-api.us-east-1.amazonaws.com/staging'),
    this.audience = 'DRIVER',
  }) : _client = client ?? http.Client();
  Future<ApplicationLegalBundle> load({bool refresh = false}) async {
    if (!refresh &&
        _cached != null &&
        _loadedAt != null &&
        DateTime.now().difference(_loadedAt!) < const Duration(minutes: 2))
      return _cached!;
    final r = await _client
        .get(Uri.parse('$baseUrl/legal')
            .replace(queryParameters: {'audience': audience}))
        .timeout(const Duration(seconds: 15));
    if (r.statusCode != 200)
      throw StateError('تعذر تحميل السياسات المنشورة. أعد المحاولة.');
    final bundle = ApplicationLegalBundle.fromJson(
      jsonDecode(utf8.decode(r.bodyBytes))['bundle'],
    );
    if (bundle.audience != audience)
      throw const FormatException('WRONG_LEGAL_AUDIENCE');
    _cached = bundle;
    _loadedAt = DateTime.now();
    return bundle;
  }
}
