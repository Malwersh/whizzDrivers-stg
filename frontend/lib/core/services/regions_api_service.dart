import 'dart:convert';

import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/environment.dart';
import '../models/region_models.dart';

class RegionsApiService {
  static String get _baseUrl => Environment.apiBaseUrl;

  static final List<Country> _fallbackCountries = [
    Country(
      regionId: 'iq',
      name: 'Iraq',
      nameAr: 'العراق',
      level: 1,
    ),
  ];

  static final List<Governorate> _fallbackGovernorates = [
    Governorate(
      regionId: 'baghdad',
      name: 'Baghdad',
      nameAr: 'بغداد',
      level: 2,
      parentId: 'iq',
    ),
    Governorate(
      regionId: 'basra',
      name: 'Basra',
      nameAr: 'البصرة',
      level: 2,
      parentId: 'iq',
    ),
    Governorate(
      regionId: 'erbil',
      name: 'Erbil',
      nameAr: 'أربيل',
      level: 2,
      parentId: 'iq',
    ),
    Governorate(
      regionId: 'najaf',
      name: 'Najaf',
      nameAr: 'النجف',
      level: 2,
      parentId: 'iq',
    ),
    Governorate(
      regionId: 'karbala',
      name: 'Karbala',
      nameAr: 'كربلاء',
      level: 2,
      parentId: 'iq',
    ),
  ];

  static final Map<String, List<ResidentialArea>> _fallbackResidentialAreas = {
    'baghdad': [
      ResidentialArea(
        regionId: 'baghdad-central',
        name: 'Baghdad Central',
        nameAr: 'وسط بغداد',
        level: 3,
        parentId: 'baghdad',
        parentDistrictName: 'بغداد',
      ),
      ResidentialArea(
        regionId: 'karrada',
        name: 'Karrada',
        nameAr: 'الكَرادة',
        level: 3,
        parentId: 'baghdad',
        parentDistrictName: 'بغداد',
      ),
      ResidentialArea(
        regionId: 'mansour',
        name: 'Al-Mansour',
        nameAr: 'المنصور',
        level: 3,
        parentId: 'baghdad',
        parentDistrictName: 'بغداد',
      ),
    ],
    'basra': [
      ResidentialArea(
        regionId: 'basra-central',
        name: 'Basra Central',
        nameAr: 'وسط البصرة',
        level: 3,
        parentId: 'basra',
        parentDistrictName: 'البصرة',
      ),
    ],
    'erbil': [
      ResidentialArea(
        regionId: 'erbil-central',
        name: 'Erbil Central',
        nameAr: 'وسط أربيل',
        level: 3,
        parentId: 'erbil',
        parentDistrictName: 'أربيل',
      ),
    ],
    'najaf': [
      ResidentialArea(
        regionId: 'najaf-central',
        name: 'Najaf Central',
        nameAr: 'وسط النجف',
        level: 3,
        parentId: 'najaf',
        parentDistrictName: 'النجف',
      ),
    ],
    'karbala': [
      ResidentialArea(
        regionId: 'karbala-central',
        name: 'Karbala Central',
        nameAr: 'وسط كربلاء',
        level: 3,
        parentId: 'karbala',
        parentDistrictName: 'كربلاء',
      ),
    ],
  };

  Future<Map<String, String>> _authHeaders() async {
    final session = await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
    final accessToken = session.userPoolTokensResult.value.accessToken.raw;

    return {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    };
  }

  /// جلب جميع البلدان (Level 0)
  Future<List<Country>> getCountries() async {
    try {
      final url = Uri.parse('$_baseUrl/regions/countries');
      final response = await http.get(
        url,
        headers: await _authHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic> && data['countries'] is List) {
          final countriesList = data['countries'] as List;
          return countriesList
              .map((c) => Country.fromJson(c as Map<String, dynamic>))
              .toList();
        }
        return _fallbackCountries;
      }
      return _fallbackCountries;
    } catch (e) {
      debugPrint('Using fallback countries due to region API error: $e');
      return _fallbackCountries;
    }
  }

  /// جلب جميع المحافظات للبلد (Level 1)
  Future<List<Governorate>> getGovernorates(String countryId) async {
    try {
      final url = Uri.parse('$_baseUrl/regions/governorates?countryId=$countryId');
      final response = await http.get(
        url,
        headers: await _authHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic> && data['governorates'] is List) {
          final governoratesList = data['governorates'] as List;
          return governoratesList
              .map((g) => Governorate.fromJson(g as Map<String, dynamic>))
              .toList();
        }
        return _fallbackGovernorates;
      }
      return _fallbackGovernorates;
    } catch (e) {
      debugPrint('Using fallback governorates due to region API error: $e');
      return _fallbackGovernorates;
    }
  }

  /// جلب مناطق السكن النشطة (Level 3 أو Level 2)
  Future<List<ResidentialArea>> getResidentialAreas(String governorateId) async {
    try {
      final url = Uri.parse('$_baseUrl/regions/residential-areas?governorateId=$governorateId');
      final response = await http.get(
        url,
        headers: await _authHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic> && data['residentialAreas'] is List) {
          final areasList = data['residentialAreas'] as List;
          return areasList
              .map((a) => ResidentialArea.fromJson(a as Map<String, dynamic>))
              .toList();
        }
      }

      final key = governorateId.trim().toLowerCase();
      return _fallbackResidentialAreas[key] ?? _fallbackResidentialAreas['baghdad'] ?? const [];
    } catch (e) {
      debugPrint('Using fallback residential areas due to region API error: $e');
      final key = governorateId.trim().toLowerCase();
      return _fallbackResidentialAreas[key] ?? _fallbackResidentialAreas['baghdad'] ?? const [];
    }
  }
}
