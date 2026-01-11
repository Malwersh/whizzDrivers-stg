class RegionalOrderService {
  // City-specific order management for Iraqi cities

  static const Map<String, Map<String, dynamic>> cityConfigs = {
    'baghdad': {
      'name_ar': 'بغداد',
      'timezone': 'Asia/Baghdad',
      'commission_rate': 0.15, // 15%
      'delivery_zones': [
        'الكرادة',
        'المنصور',
        'الجادرية',
        'الكاظمية',
        'الأعظمية',
        'البياع',
        'الدورة',
        'الزعفرانية',
        'المدائن',
      ],
      'peak_hours': ['12:00-14:00', '19:00-22:00'],
      'min_order_value': 15000, // 15,000 IQD
    },
    'basra': {
      'name_ar': 'البصرة',
      'timezone': 'Asia/Baghdad',
      'commission_rate': 0.12, // 12%
      'delivery_zones': [
        'المعقل',
        'البصرة القديمة',
        'الجمهورية',
        'الحكيمية',
        'التميمي',
        'الجزائر',
        'المدينة',
        'الهارثة',
      ],
      'peak_hours': ['12:30-14:30', '19:30-22:30'],
      'min_order_value': 12000, // 12,000 IQD
    },
    'erbil': {
      'name_ar': 'أربيل',
      'name_ku': 'هەولێر',
      'timezone': 'Asia/Baghdad',
      'commission_rate': 0.18, // 18%
      'delivery_zones': [
        'ناوەندی شار',
        'عنكاوا',
        'شورش',
        'رێگای ئیران',
        'ئەندازیارەکان',
        'باختیاری',
        'کوردستان',
      ],
      'peak_hours': ['12:00-14:00', '19:00-22:00'],
      'min_order_value': 18000, // 18,000 IQD
    },
  };

  static Map<String, dynamic>? getCityConfig(String cityCode) {
    return cityConfigs[cityCode.toLowerCase()];
  }

  static List<String> getDeliveryZones(String cityCode) {
    final config = getCityConfig(cityCode);
    return config != null ? List<String>.from(config['delivery_zones']) : [];
  }

  static double getCommissionRate(String cityCode) {
    final config = getCityConfig(cityCode);
    return config?['commission_rate'] ?? 0.15;
  }

  static int getMinOrderValue(String cityCode) {
    final config = getCityConfig(cityCode);
    return config?['min_order_value'] ?? 15000;
  }

  static List<String> getPeakHours(String cityCode) {
    final config = getCityConfig(cityCode);
    return config != null ? List<String>.from(config['peak_hours']) : [];
  }

  static bool isPeakHour(String cityCode) {
    final peakHours = getPeakHours(cityCode);
    final now = DateTime.now();
    final currentTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    for (final peakHour in peakHours) {
      final times = peakHour.split('-');
      if (times.length == 2) {
        final start = times[0];
        final end = times[1];
        if (currentTime.compareTo(start) >= 0 &&
            currentTime.compareTo(end) <= 0) {
          return true;
        }
      }
    }
    return false;
  }

  static double calculateEarnings({
    required String cityCode,
    required double orderValue,
    required double deliveryDistance,
    bool isExpress = false,
  }) {
    final commissionRate = getCommissionRate(cityCode);
    final baseEarning = orderValue * commissionRate;

    // Distance bonus (500 IQD per km after 2km)
    double distanceBonus = 0;
    if (deliveryDistance > 2.0) {
      distanceBonus = (deliveryDistance - 2.0) * 500;
    }

    // Peak hour bonus (25% extra)
    double peakBonus = 0;
    if (isPeakHour(cityCode)) {
      peakBonus = baseEarning * 0.25;
    }

    // Express delivery bonus (1000 IQD)
    double expressBonus = isExpress ? 1000 : 0;

    return baseEarning + distanceBonus + peakBonus + expressBonus;
  }

  static String formatCurrency(double amount) {
    return '${amount.toStringAsFixed(0)} د.ع'; // Iraqi Dinar formatting
  }

  static String getCityNameInArabic(String cityCode) {
    final config = getCityConfig(cityCode);
    return config?['name_ar'] ?? cityCode;
  }

  static String? getCityNameInKurdish(String cityCode) {
    final config = getCityConfig(cityCode);
    return config?['name_ku'];
  }
}
