import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/region_models.dart';

class RegionsApiService {
  static const String _baseUrl = 'https://z52h5bqm15.execute-api.us-east-1.amazonaws.com';
  
  /// جلب جميع البلدان (Level 0)
  Future<List<Country>> getCountries() async {
    try {
      final url = Uri.parse('$_baseUrl/regions/countries');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final List countriesList = data['countries'] as List;
        return countriesList
            .map((c) => Country.fromJson(c as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to load countries: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching countries: $e');
    }
  }
  
  /// جلب جميع المحافظات للبلد (Level 1)
  Future<List<Governorate>> getGovernorates(String countryId) async {
    try {
      final url = Uri.parse('$_baseUrl/regions/governorates?countryId=$countryId');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final List governoratesList = data['governorates'] as List;
        return governoratesList
            .map((g) => Governorate.fromJson(g as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to load governorates: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching governorates: $e');
    }
  }

  /// جلب مناطق السكن النشطة (Level 3 أو Level 2)
  Future<List<ResidentialArea>> getResidentialAreas(String governorateId) async {
    try {
      final url = Uri.parse('$_baseUrl/regions/residential-areas?governorateId=$governorateId');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final List areasList = data['residentialAreas'] as List;
        return areasList
            .map((a) => ResidentialArea.fromJson(a as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to load residential areas: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching residential areas: $e');
    }
  }
}
