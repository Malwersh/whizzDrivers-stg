import 'package:flutter_test/flutter_test.dart';
import '../lib/utils/iraqi_phone.dart';
void main() {
  test('Iraq formats normalize to the same identity', () {
    for (final number in ['07701234567', '7701234567', '+9647701234567', '9647701234567', '009647701234567', '٠٧٧٠١٢٣٤٥٦٧', '۰۷۷۰۱۲۳۴۵۶۷', '+964 (770) 123-4567']) {
      expect(IraqiPhone.normalize(number), '+9647701234567');
    }
  });
  test('foreign and malformed numbers are rejected', () {
    for (final number in ['+15551234567', '+971501234567', '+9641770123456', '0770123456', '077012345678', '+96407701234567', 'abc07701234567', '++9647701234567', '']) {
      expect(IraqiPhone.isValid(number), isFalse);
      expect(() => IraqiPhone.normalize(number), throwsFormatException);
    }
  });
}
