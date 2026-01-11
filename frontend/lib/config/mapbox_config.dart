import 'package:shared_preferences/shared_preferences.dart';

class MapboxConfig {
  // Mapbox API Configuration
  static const String _keyMapboxAccessToken = 'mapbox_access_token';
  static const String _keyMapboxStyleUrl = 'mapbox_style_url';
  static const String _keyMapboxLanguage = 'mapbox_language';

  // Default Mapbox settings
  static const String _defaultStyleUrl = 'mapbox://styles/mapbox/streets-v11';
  static const String _defaultLanguage = 'ar'; // Arabic for Iraq

  // Iraqi cities coordinates with proper Arabic names
  static const Map<String, Map<String, dynamic>> cityCoordinates = {
    'Baghdad': {
      'lat': 33.3152,
      'lng': 44.3661,
      'name_ar': 'بغداد',
      'name_en': 'Baghdad',
      'zoom': 10.0,
      'bounds': {
        'southwest': {'lat': 33.1, 'lng': 44.2},
        'northeast': {'lat': 33.5, 'lng': 44.5},
      },
    },
    'Basra': {
      'lat': 30.5081,
      'lng': 47.7804,
      'name_ar': 'البصرة',
      'name_en': 'Basra',
      'zoom': 10.0,
      'bounds': {
        'southwest': {'lat': 30.3, 'lng': 47.6},
        'northeast': {'lat': 30.7, 'lng': 47.9},
      },
    },
    'Erbil': {
      'lat': 36.1901,
      'lng': 43.9930,
      'name_ar': 'أربيل',
      'name_en': 'Erbil',
      'zoom': 10.0,
      'bounds': {
        'southwest': {'lat': 36.0, 'lng': 43.8},
        'northeast': {'lat': 36.4, 'lng': 44.1},
      },
    },
    'Mosul': {
      'lat': 36.3450,
      'lng': 43.1450,
      'name_ar': 'الموصل',
      'name_en': 'Mosul',
      'zoom': 10.0,
      'bounds': {
        'southwest': {'lat': 36.2, 'lng': 43.0},
        'northeast': {'lat': 36.5, 'lng': 43.3},
      },
    },
    'Najaf': {
      'lat': 32.0000,
      'lng': 44.3333,
      'name_ar': 'النجف',
      'name_en': 'Najaf',
      'zoom': 11.0,
      'bounds': {
        'southwest': {'lat': 31.8, 'lng': 44.2},
        'northeast': {'lat': 32.2, 'lng': 44.5},
      },
    },
    'Karbala': {
      'lat': 32.6167,
      'lng': 44.0333,
      'name_ar': 'كربلاء',
      'name_en': 'Karbala',
      'zoom': 11.0,
      'bounds': {
        'southwest': {'lat': 32.5, 'lng': 43.9},
        'northeast': {'lat': 32.7, 'lng': 44.1},
      },
    },
  };

  // Map styles for different use cases
  static const Map<String, String> mapStyles = {
    'streets': 'mapbox://styles/mapbox/streets-v11',
    'outdoors': 'mapbox://styles/mapbox/outdoors-v11',
    'light': 'mapbox://styles/mapbox/light-v10',
    'dark': 'mapbox://styles/mapbox/dark-v10',
    'satellite': 'mapbox://styles/mapbox/satellite-v9',
    'satellite_streets': 'mapbox://styles/mapbox/satellite-streets-v11',
  };

  // Route optimization settings
  static const Map<String, dynamic> routeSettings = {
    'profile': 'driving-traffic', // driving, driving-traffic, walking, cycling
    'alternatives': true,
    'annotations': ['duration', 'distance', 'speed'],
    'overview': 'full',
    'steps': true,
    'continue_straight': true,
  };

  // Geofencing settings
  static const Map<String, dynamic> geofenceSettings = {
    'radius_meters': 5000, // 5km radius for city boundaries
    'enter_threshold': 100, // meters
    'exit_threshold': 200, // meters
    'dwell_time': 300, // seconds
  };

  // Traffic settings
  static const Map<String, dynamic> trafficSettings = {
    'enable_traffic': true,
    'traffic_style': 'mapbox://styles/mapbox/traffic-day-v2',
    'update_interval': 300, // seconds
  };

  // Map interaction settings
  static const Map<String, dynamic> interactionSettings = {
    'enable_rotation': true,
    'enable_tilt': true,
    'enable_zoom': true,
    'enable_scroll': true,
    'max_zoom': 18.0,
    'min_zoom': 8.0,
  };

  // Driver tracking settings
  static const Map<String, dynamic> trackingSettings = {
    'update_interval': 10, // seconds
    'accuracy_filter': 10.0, // meters
    'enable_background_tracking': true,
    'enable_geofencing': true,
    'enable_route_matching': true,
  };

  // Static methods for configuration
  static Future<String> get accessToken async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyMapboxAccessToken) ?? '';
  }

  static Future<void> setAccessToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMapboxAccessToken, token);
  }

  static Future<String> get styleUrl async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyMapboxStyleUrl) ?? _defaultStyleUrl;
  }

  static Future<void> setStyleUrl(String styleUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMapboxStyleUrl, styleUrl);
  }

  static Future<String> get language async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyMapboxLanguage) ?? _defaultLanguage;
  }

  static Future<void> setLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMapboxLanguage, language);
  }

  // Utility methods
  static Map<String, dynamic>? getCityCoordinates(String cityName) {
    return cityCoordinates[cityName];
  }

  static List<String> getSupportedCities() {
    return cityCoordinates.keys.toList();
  }

  static List<String> getSupportedCitiesArabic() {
    return cityCoordinates.values
        .map((city) => city['name_ar'] as String)
        .toList();
  }

  static List<String> getSupportedCitiesEnglish() {
    return cityCoordinates.values
        .map((city) => city['name_en'] as String)
        .toList();
  }

  static String getCityNameInLanguage(String cityName, String language) {
    final city = cityCoordinates[cityName];
    if (city == null) return cityName;

    return language == 'ar' ? city['name_ar'] : city['name_en'];
  }

  static Map<String, dynamic> getMapBounds(String cityName) {
    final city = cityCoordinates[cityName];
    return city?['bounds'] ?? {};
  }

  static double getCityZoom(String cityName) {
    final city = cityCoordinates[cityName];
    return city?['zoom'] ?? 10.0;
  }

  // Route calculation utilities
  static Future<String> buildRouteUrl({
    required List<List<double>> coordinates,
    String profile = 'driving-traffic',
    bool alternatives = true,
    List<String> annotations = const ['duration', 'distance'],
  }) async {
    final token = await accessToken;
    final baseUrl = 'https://api.mapbox.com/directions/v5/mapbox/$profile/';
    final coords = coordinates
        .map((coord) => '${coord[0]},${coord[1]}')
        .join(';');
    final params = {
      'access_token': token,
      'alternatives': alternatives.toString(),
      'annotations': annotations.join(','),
      'overview': 'full',
      'steps': 'true',
      'continue_straight': 'true',
    };

    final queryString = params.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');
    return '$baseUrl$coords?$queryString';
  }

  // Geocoding utilities
  static Future<String> buildGeocodingUrl({
    required String query,
    String language = 'ar',
    List<double>? proximity,
    List<String> types = const ['place', 'neighborhood', 'address'],
  }) async {
    final token = await accessToken;
    const baseUrl = 'https://api.mapbox.com/geocoding/v5/mapbox.places/';
    final encodedQuery = Uri.encodeComponent(query);
    final params = {
      'access_token': token,
      'language': language,
      'types': types.join(','),
      'limit': '5',
    };

    if (proximity != null) {
      params['proximity'] = '${proximity[0]},${proximity[1]}';
    }

    final queryString = params.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');
    return '$baseUrl$encodedQuery.json?$queryString';
  }

  // Reverse geocoding utilities
  static Future<String> buildReverseGeocodingUrl({
     required double longitude,
     required double latitude,
     String language = 'ar',
     List<String> types = const ['place', 'neighborhood', 'address'],
   }) async {
    final token = await accessToken;
    const baseUrl = 'https://api.mapbox.com/geocoding/v5/mapbox.places/';
    final coords = '$longitude,$latitude';
    final params = {
      'access_token': token,
      'language': language,
      'types': types.join(','),
      'limit': '1',
    };

    final queryString = params.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');
    return '$baseUrl$coords.json?$queryString';
  }

  // Debug information
  static Future<Map<String, dynamic>> getDebugInfo() async {
    return {
      'access_token_configured': (await accessToken).isNotEmpty,
      'style_url': await styleUrl,
      'language': await language,
      'supported_cities': getSupportedCities(),
      'supported_cities_count': cityCoordinates.length,
    };
  }
}
