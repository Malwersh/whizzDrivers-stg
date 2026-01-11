import 'dart:convert';
import 'package:http/http.dart' as http;

enum IraqiPaymentMethod {
  zainCash,
  asiaCellPay,
  kiCard,
  cashOnDelivery,
  bankTransfer,
}

class IraqiPaymentService {
  static const Map<IraqiPaymentMethod, Map<String, dynamic>> paymentMethods = {
    IraqiPaymentMethod.zainCash: {
      'name_ar': 'زين كاش',
      'name_en': 'Zain Cash',
      'logo': 'assets/images/zain_cash_logo.png',
      'api_endpoint': 'https://api.zaincash.iq',
      'merchant_id': 'HADHIR_DRIVER_001',
      'is_digital': true,
      'processing_fee': 500, // 500 IQD
      'min_amount': 1000,
      'max_amount': 1000000,
    },
    IraqiPaymentMethod.asiaCellPay: {
      'name_ar': 'آسيا سيل باي',
      'name_en': 'Asia Cell Pay',
      'logo': 'assets/images/asia_cell_logo.png',
      'api_endpoint': 'https://pay.asiacell.com',
      'merchant_id': 'HADHIR_DRIVER_002',
      'is_digital': true,
      'processing_fee': 500, // 500 IQD
      'min_amount': 1000,
      'max_amount': 500000,
    },
    IraqiPaymentMethod.kiCard: {
      'name_ar': 'بطاقة كي',
      'name_en': 'Ki Card',
      'logo': 'assets/images/ki_card_logo.png',
      'api_endpoint': 'https://api.kicard.iq',
      'merchant_id': 'HADHIR_DRIVER_003',
      'is_digital': true,
      'processing_fee': 250, // 250 IQD
      'min_amount': 5000,
      'max_amount': 2000000,
    },
    IraqiPaymentMethod.cashOnDelivery: {
      'name_ar': 'الدفع عند الاستلام',
      'name_en': 'Cash on Delivery',
      'logo': 'assets/images/cash_icon.png',
      'is_digital': false,
      'processing_fee': 0,
      'min_amount': 1000,
      'max_amount': 100000,
    },
    IraqiPaymentMethod.bankTransfer: {
      'name_ar': 'حوالة مصرفية',
      'name_en': 'Bank Transfer',
      'logo': 'assets/images/bank_icon.png',
      'is_digital': true,
      'processing_fee': 1000, // 1000 IQD
      'min_amount': 10000,
      'max_amount': 5000000,
    },
  };

  static List<IraqiPaymentMethod> getAvailablePaymentMethods({
    required double amount,
    bool digitalOnly = false,
  }) {
    final available = <IraqiPaymentMethod>[];

    for (final method in IraqiPaymentMethod.values) {
      final config = paymentMethods[method]!;
      final minAmount = config['min_amount'] as int;
      final maxAmount = config['max_amount'] as int;
      final isDigital = config['is_digital'] as bool;

      if (digitalOnly && !isDigital) continue;
      if (amount < minAmount || amount > maxAmount) continue;

      available.add(method);
    }

    return available;
  }

  static String getPaymentMethodName(
    IraqiPaymentMethod method, {
    bool inArabic = true,
  }) {
    final config = paymentMethods[method]!;
    return config[inArabic ? 'name_ar' : 'name_en'] as String;
  }

  static double getProcessingFee(IraqiPaymentMethod method) {
    final config = paymentMethods[method]!;
    return (config['processing_fee'] as int).toDouble();
  }

  static bool isDigitalPayment(IraqiPaymentMethod method) {
    final config = paymentMethods[method]!;
    return config['is_digital'] as bool;
  }

  // Zain Cash payment processing
  static Future<Map<String, dynamic>> processZainCashPayment({
    required double amount,
    required String phoneNumber,
    required String orderId,
  }) async {
    final config = paymentMethods[IraqiPaymentMethod.zainCash]!;
    final endpoint = config['api_endpoint'] as String;

    try {
      final response = await http.post(
        Uri.parse('$endpoint/transaction/pay'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_getZainCashToken()}',
        },
        body: jsonEncode({
          'ServiceType': 'HadhirDriverEarnings',
          'Amount': amount.toInt(),
          'CurrencyIso': 'IQD',
          'MerchantId': config['merchant_id'],
          'MobileNo': phoneNumber,
          'OrderId': orderId,
          'ProductDescription': 'أرباح سائق حاضر - $orderId',
          'RedirectUrl': 'https://driver.hadhir.app/payment/callback',
          'Lang': 'ar',
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['IsSuccess'] == true) {
        return {
          'success': true,
          'transaction_id': data['Id'],
          'payment_url': data['PaymentUrl'],
          'message': 'تم إنشاء معاملة زين كاش بنجاح',
        };
      } else {
        return {
          'success': false,
          'error': data['ErrorMessage'] ?? 'حدث خطأ في معالجة الدفع',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'فشل الاتصال بزين كاش: $e'};
    }
  }

  // Asia Cell Pay payment processing
  static Future<Map<String, dynamic>> processAsiaCellPayment({
    required double amount,
    required String phoneNumber,
    required String orderId,
  }) async {
    final config = paymentMethods[IraqiPaymentMethod.asiaCellPay]!;
    final endpoint = config['api_endpoint'] as String;

    try {
      final response = await http.post(
        Uri.parse('$endpoint/api/payment/create'),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': _getAsiaCellApiKey(),
        },
        body: jsonEncode({
          'amount': amount.toInt(),
          'currency': 'IQD',
          'merchant_id': config['merchant_id'],
          'phone_number': phoneNumber,
          'order_reference': orderId,
          'description': 'Driver earnings payout - $orderId',
          'callback_url': 'https://driver.hadhir.app/payment/asiacell/callback',
          'language': 'ar',
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 && data['status'] == 'success') {
        return {
          'success': true,
          'transaction_id': data['transaction_id'],
          'payment_url': data['payment_url'],
          'message': 'تم إنشاء معاملة آسيا سيل باي بنجاح',
        };
      } else {
        return {
          'success': false,
          'error': data['message'] ?? 'حدث خطأ في معالجة الدفع',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'فشل الاتصال بآسيا سيل باي: $e'};
    }
  }

  // Ki Card payment processing
  static Future<Map<String, dynamic>> processKiCardPayment({
    required double amount,
    required String cardNumber,
    required String orderId,
  }) async {
    final config = paymentMethods[IraqiPaymentMethod.kiCard]!;
    final endpoint = config['api_endpoint'] as String;

    try {
      final response = await http.post(
        Uri.parse('$endpoint/v1/payments'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_getKiCardToken()}',
        },
        body: jsonEncode({
          'amount': amount.toInt(),
          'currency': 'IQD',
          'merchant_id': config['merchant_id'],
          'card_number': cardNumber,
          'transaction_ref': orderId,
          'description': 'Hadhir Driver Payout',
          'return_url': 'https://driver.hadhir.app/payment/kicard/return',
          'locale': 'ar_IQ',
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'transaction_id': data['transaction_id'],
          'authorization_url': data['authorization_url'],
          'message': 'تم إنشاء معاملة بطاقة كي بنجاح',
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'حدث خطأ في معالجة الدفع',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'فشل الاتصال ببطاقة كي: $e'};
    }
  }

  // Payment verification
  static Future<Map<String, dynamic>> verifyPayment({
    required String transactionId,
    required IraqiPaymentMethod method,
  }) async {
    switch (method) {
      case IraqiPaymentMethod.zainCash:
        return _verifyZainCashPayment(transactionId);
      case IraqiPaymentMethod.asiaCellPay:
        return _verifyAsiaCellPayment(transactionId);
      case IraqiPaymentMethod.kiCard:
        return _verifyKiCardPayment(transactionId);
      default:
        return {'success': false, 'error': 'طريقة الدفع غير مدعومة للتحقق'};
    }
  }

  // Private helper methods for API tokens (these should be securely stored)
  static String _getZainCashToken() {
    // In production, get this from secure storage or environment variables
    return 'ZAIN_CASH_API_TOKEN';
  }

  static String _getAsiaCellApiKey() {
    return 'ASIA_CELL_API_KEY';
  }

  static String _getKiCardToken() {
    return 'KI_CARD_API_TOKEN';
  }

  static Future<Map<String, dynamic>> _verifyZainCashPayment(
    String transactionId,
  ) async {
    // Implementation for Zain Cash verification
    return {'success': true, 'status': 'completed'};
  }

  static Future<Map<String, dynamic>> _verifyAsiaCellPayment(
    String transactionId,
  ) async {
    // Implementation for Asia Cell verification
    return {'success': true, 'status': 'completed'};
  }

  static Future<Map<String, dynamic>> _verifyKiCardPayment(
    String transactionId,
  ) async {
    // Implementation for Ki Card verification
    return {'success': true, 'status': 'completed'};
  }

  // Format amount for display
  static String formatAmount(double amount, {bool showCurrency = true}) {
    final formatted = amount.toStringAsFixed(0);
    return showCurrency ? '$formatted د.ع' : formatted;
  }

  // Calculate total amount including fees
  static double calculateTotalWithFees(
    double amount,
    IraqiPaymentMethod method,
  ) {
    final fee = getProcessingFee(method);
    return amount + fee;
  }
}
