/// Iraq mobile numbers only; returns canonical E.164.
class IraqiPhone {
  static String normalize(String input) {
    final digits = input.trim().split('').map((c) {
      final n = c.codeUnitAt(0);
      if (n >= 0x660 && n <= 0x669) return '${n - 0x660}';
      if (n >= 0x6f0 && n <= 0x6f9) return '${n - 0x6f0}';
      return c;
    }).join().replaceAll(RegExp(r'[\s()\-]'), '');
    String national;
    if (RegExp(r'^\+9647[0-9]{9}$').hasMatch(digits)) {
      national = digits.substring(4);
    } else if (RegExp(r'^009647[0-9]{9}$').hasMatch(digits)) {
      national = digits.substring(5);
    } else if (RegExp(r'^9647[0-9]{9}$').hasMatch(digits)) {
      national = digits.substring(3);
    } else if (RegExp(r'^07[0-9]{9}$').hasMatch(digits)) {
      national = digits.substring(1);
    } else if (RegExp(r'^7[0-9]{9}$').hasMatch(digits)) {
      national = digits;
    } else {
      throw const FormatException('يُسمح بأرقام الهاتف العراقية فقط (+964)');
    }
    return '+964$national';
  }

  static bool isValid(String input) {
    try {
      normalize(input);
      return true;
    } on FormatException {
      return false;
    }
  }
}
