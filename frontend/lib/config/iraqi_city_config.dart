class IraqiCityConfig {
  static const Map<String, Map<String, dynamic>> cities = {
    'baghdad': {
      'id': 'baghdad',
      'name_en': 'Baghdad',
      'name_ar': 'بغداد',
      'latitude': 33.3152,
      'longitude': 44.3661,
      'timezone': 'Asia/Baghdad',
      'is_active': true,
      'launch_date': '2025-06-01',
      'commission_rate': 0.15,
      'delivery_zones': [
        {
          'name_ar': 'الكرادة',
          'name_en': 'Al-Karrada',
          'bounds': {
            'north': 33.3200,
            'south': 33.3000,
            'east': 44.3800,
            'west': 44.3500,
          },
        },
        {
          'name_ar': 'المنصور',
          'name_en': 'Al-Mansour',
          'bounds': {
            'north': 33.3300,
            'south': 33.3100,
            'east': 44.3400,
            'west': 44.3200,
          },
        },
        {
          'name_ar': 'الجادرية',
          'name_en': 'Al-Jadriya',
          'bounds': {
            'north': 33.2800,
            'south': 33.2600,
            'east': 44.3700,
            'west': 44.3500,
          },
        },
        {
          'name_ar': 'الكاظمية',
          'name_en': 'Al-Kadhimiya',
          'bounds': {
            'north': 33.3800,
            'south': 33.3600,
            'east': 44.3400,
            'west': 44.3200,
          },
        },
        {
          'name_ar': 'الأعظمية',
          'name_en': 'Al-Adhamiya',
          'bounds': {
            'north': 33.3600,
            'south': 33.3400,
            'east': 44.3800,
            'west': 44.3600,
          },
        },
      ],
      'peak_hours': ['12:00-14:00', '19:00-22:00'],
      'min_order_value': 15000,
      'avg_delivery_time': 35,
      'supported_payments': ['zain_cash', 'asia_cell_pay', 'cash_on_delivery'],
    },

    'basra': {
      'id': 'basra',
      'name_en': 'Basra',
      'name_ar': 'البصرة',
      'latitude': 30.5085,
      'longitude': 47.7804,
      'timezone': 'Asia/Baghdad',
      'is_active': false,
      'launch_date': '2025-08-01',
      'commission_rate': 0.12,
      'delivery_zones': [
        {
          'name_ar': 'المعقل',
          'name_en': 'Al-Maqal',
          'bounds': {
            'north': 30.5200,
            'south': 30.5000,
            'east': 47.8000,
            'west': 47.7700,
          },
        },
        {
          'name_ar': 'البصرة القديمة',
          'name_en': 'Old Basra',
          'bounds': {
            'north': 30.5100,
            'south': 30.4900,
            'east': 47.7900,
            'west': 47.7600,
          },
        },
      ],
      'peak_hours': ['12:30-14:30', '19:30-22:30'],
      'min_order_value': 12000,
      'avg_delivery_time': 30,
      'supported_payments': ['cash_on_delivery', 'zain_cash'],
    },

    'erbil': {
      'id': 'erbil',
      'name_en': 'Erbil',
      'name_ar': 'أربيل',
      'name_ku': 'هەولێر',
      'latitude': 36.1911,
      'longitude': 44.0093,
      'timezone': 'Asia/Baghdad',
      'is_active': false,
      'launch_date': '2025-07-01',
      'commission_rate': 0.18,
      'delivery_zones': [
        {
          'name_ar': 'مركز المدينة',
          'name_en': 'City Center',
          'name_ku': 'ناوەندی شار',
          'bounds': {
            'north': 36.2000,
            'south': 36.1800,
            'east': 44.0200,
            'west': 44.0000,
          },
        },
        {
          'name_ar': 'عنكاوا',
          'name_en': 'Ankawa',
          'name_ku': 'عەنکاوا',
          'bounds': {
            'north': 36.2200,
            'south': 36.2000,
            'east': 44.0400,
            'west': 44.0200,
          },
        },
      ],
      'peak_hours': ['12:00-14:00', '19:00-22:00'],
      'min_order_value': 18000,
      'avg_delivery_time': 32,
      'supported_payments': ['ki_card', 'zain_cash', 'cash_on_delivery'],
    },

    'mosul': {
      'id': 'mosul',
      'name_en': 'Mosul',
      'name_ar': 'الموصل',
      'latitude': 36.3350,
      'longitude': 43.1189,
      'timezone': 'Asia/Baghdad',
      'is_active': false,
      'launch_date': '2025-10-01',
      'commission_rate': 0.14,
      'delivery_zones': [
        {
          'name_ar': 'الجانب الأيمن',
          'name_en': 'Right Bank',
          'bounds': {
            'north': 36.3500,
            'south': 36.3200,
            'east': 43.1400,
            'west': 43.1000,
          },
        },
        {
          'name_ar': 'الجانب الأيسر',
          'name_en': 'Left Bank',
          'bounds': {
            'north': 36.3400,
            'south': 36.3100,
            'east': 43.1300,
            'west': 43.0900,
          },
        },
      ],
      'peak_hours': ['12:00-14:00', '19:00-22:00'],
      'min_order_value': 13000,
      'avg_delivery_time': 40,
      'supported_payments': ['cash_on_delivery', 'zain_cash'],
    },

    'najaf': {
      'id': 'najaf',
      'name_en': 'Najaf',
      'name_ar': 'النجف',
      'latitude': 31.9996,
      'longitude': 44.3267,
      'timezone': 'Asia/Baghdad',
      'is_active': false,
      'launch_date': '2025-09-01',
      'commission_rate': 0.13,
      'delivery_zones': [
        {
          'name_ar': 'المركز',
          'name_en': 'Center',
          'bounds': {
            'north': 32.0100,
            'south': 31.9900,
            'east': 44.3400,
            'west': 44.3100,
          },
        },
      ],
      'peak_hours': ['12:00-14:00', '19:00-22:00'],
      'min_order_value': 12000,
      'avg_delivery_time': 28,
      'supported_payments': ['cash_on_delivery', 'zain_cash'],
    },

    'karbala': {
      'id': 'karbala',
      'name_en': 'Karbala',
      'name_ar': 'كربلاء',
      'latitude': 32.6160,
      'longitude': 44.0242,
      'timezone': 'Asia/Baghdad',
      'is_active': false,
      'launch_date': '2025-09-15',
      'commission_rate': 0.13,
      'delivery_zones': [
        {
          'name_ar': 'المركز',
          'name_en': 'Center',
          'bounds': {
            'north': 32.6300,
            'south': 32.6000,
            'east': 44.0400,
            'west': 44.0100,
          },
        },
      ],
      'peak_hours': ['12:00-14:00', '19:00-22:00'],
      'min_order_value': 12000,
      'avg_delivery_time': 25,
      'supported_payments': ['cash_on_delivery', 'zain_cash'],
    },
  };

  static List<String> getActiveCities() {
    return cities.entries
        .where((entry) => entry.value['is_active'] == true)
        .map((entry) => entry.key)
        .toList();
  }

  static List<String> getAllCities() {
    return cities.keys.toList();
  }

  static Map<String, dynamic>? getCityConfig(String cityId) {
    return cities[cityId.toLowerCase()];
  }

  static String getCityName(String cityId, {String language = 'ar'}) {
    final config = getCityConfig(cityId);
    if (config == null) return cityId;

    switch (language) {
      case 'ar':
        return config['name_ar'] ?? config['name_en'];
      case 'ku':
        return config['name_ku'] ?? config['name_ar'] ?? config['name_en'];
      case 'en':
      default:
        return config['name_en'];
    }
  }

  static List<Map<String, dynamic>> getDeliveryZones(String cityId) {
    final config = getCityConfig(cityId);
    return config != null
        ? List<Map<String, dynamic>>.from(config['delivery_zones'])
        : [];
  }

  static bool isCityActive(String cityId) {
    final config = getCityConfig(cityId);
    return config?['is_active'] ?? false;
  }

  static DateTime? getCityLaunchDate(String cityId) {
    final config = getCityConfig(cityId);
    final dateStr = config?['launch_date'];
    return dateStr != null ? DateTime.parse(dateStr) : null;
  }

  static double getCityCommissionRate(String cityId) {
    final config = getCityConfig(cityId);
    return config?['commission_rate'] ?? 0.15;
  }

  static List<String> getSupportedPayments(String cityId) {
    final config = getCityConfig(cityId);
    return config != null
        ? List<String>.from(config['supported_payments'])
        : [];
  }

  static int getMinOrderValue(String cityId) {
    final config = getCityConfig(cityId);
    return config?['min_order_value'] ?? 15000;
  }

  static int getAvgDeliveryTime(String cityId) {
    final config = getCityConfig(cityId);
    return config?['avg_delivery_time'] ?? 30;
  }

  static List<String> getPeakHours(String cityId) {
    final config = getCityConfig(cityId);
    return config != null ? List<String>.from(config['peak_hours']) : [];
  }

  // Check if an address is within city delivery zones
  static bool isWithinDeliveryZone(
    String cityId,
    double latitude,
    double longitude,
  ) {
    final zones = getDeliveryZones(cityId);

    for (final zone in zones) {
      final bounds = zone['bounds'];
      if (latitude >= bounds['south'] &&
          latitude <= bounds['north'] &&
          longitude >= bounds['west'] &&
          longitude <= bounds['east']) {
        return true;
      }
    }

    return false;
  }

  // Get nearest delivery zone name
  static String? getNearestZoneName(
    String cityId,
    double latitude,
    double longitude, {
    String language = 'ar',
  }) {
    final zones = getDeliveryZones(cityId);

    for (final zone in zones) {
      final bounds = zone['bounds'];
      if (latitude >= bounds['south'] &&
          latitude <= bounds['north'] &&
          longitude >= bounds['west'] &&
          longitude <= bounds['east']) {
        switch (language) {
          case 'ar':
            return zone['name_ar'];
          case 'ku':
            return zone['name_ku'] ?? zone['name_ar'];
          case 'en':
          default:
            return zone['name_en'];
        }
      }
    }

    return null;
  }
}
