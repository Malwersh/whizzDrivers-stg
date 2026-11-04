import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/environment.dart';
import 'cognito_token_service.dart';

class DriverVehicleService {
  static String message(String code) => switch (code) {
        'VEHICLE_CHANGE_REQUIRES_OFFLINE' =>
          'أوقف استقبال الطلبات وأكمل الطلب الجاري قبل تغيير المركبة أو إزالتها.',
        'VEHICLE_VERSION_CONFLICT' =>
          'تغيرت البيانات. حدّث الصفحة ثم حاول مجددًا.',
        'VEHICLE_INITIAL_REVIEW_REQUIRED' =>
          'مركبتك المسجلة تحتاج إلى مراجعة أولية من الإدارة.',
        'ACTIVE_VEHICLE_NOT_APPROVED' =>
          'اختر مركبة معتمدة وصالحة للعمل من القائمة أدناه.',
        'DRIVER_DOCUMENT_REVIEW_REQUIRED' =>
          'تحتاج إجازة السوق أو البطاقة الوطنية إلى مراجعة الإدارة.',
        'DRIVER_ACCOUNT_NOT_APPROVED' =>
          'الحساب غير مؤهل للعمل حاليًا. تواصل مع الدعم.',
        'VEHICLE_LIMIT_OR_DUPLICATE' =>
          'المركبة مسجلة بالفعل أو وصلت إلى الحد المتاح.',
        'VEHICLE_PLATE_ALREADY_REGISTERED' =>
          'رقم اللوحة مسجل ضمن مركباتك بالفعل.',
        'VEHICLE_DATA_INVALID' => 'تحقق من بيانات المركبة وأرفق صورة سنويتها.',
        'VEHICLE_HISTORY_CAPACITY_REQUIRES_ARCHIVE' =>
          'بلغ سجل المركبات سعته المتاحة. تواصل مع الدعم لحفظ الأرشيف وإكمال العملية.',
        'VEHICLE_NOT_FOUND' => 'المركبة لم تعد متاحة. حدّث القائمة.',
        _ => 'تعذر إكمال العملية. حدّث الصفحة وحاول مرة أخرى.',
      };
  static Future<Map<String, dynamic>> request(
      [Map<String, dynamic>? body]) async {
    final token = await CognitoTokenService.getAccessToken();
    if (token == null) throw StateError('يرجى تسجيل الدخول مجددًا.');
    final uri = Uri.parse('${Environment.apiBaseUrl}/driver/vehicles');
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json'
    };
    final response = await (body == null
            ? http.get(uri, headers: headers)
            : http.post(uri, headers: headers, body: jsonEncode(body)))
        .timeout(const Duration(seconds: 25));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200)
      throw StateError(message(data['error']?.toString() ?? ''));
    return data;
  }
}
