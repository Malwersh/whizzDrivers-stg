import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import '../models/delivery_equipment.dart';
import 'api_service.dart';

class DeliveryEquipmentService {
  static const String _baseUrl = 'https://your-backend-url.com/api/v1';

  // Remove all code related to mock data, development mode, and local fallback
  // Only keep real API logic using AWS endpoints

  // Get all equipment types
  static Future<List<EquipmentType>> getEquipmentTypes() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/equipment/types'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${ApiService.authToken}',
          'Accept-Language': 'ar',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return (data['data'] as List)
              .map((json) => EquipmentType.fromJson(json))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching equipment types: $e');
      return [];
    }
  }

  // Get driver's equipment
  static Future<List<DeliveryEquipment>> getDriverEquipment() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/driver/equipment'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${ApiService.authToken}',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return (data['data'] as List)
              .map((json) => DeliveryEquipment.fromJson(json))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching driver equipment: $e');
      return [];
    }
  }

  // Add new equipment
  static Future<bool> addEquipment(DeliveryEquipment equipment) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/driver/equipment'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${ApiService.authToken}',
        },
        body: jsonEncode(equipment.toJson()),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error adding equipment: $e');
      return false;
    }
  }

  // Update equipment
  static Future<bool> updateEquipment(DeliveryEquipment equipment) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/driver/equipment/${equipment.id}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${ApiService.authToken}',
        },
        body: jsonEncode(equipment.toJson()),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating equipment: $e');
      return false;
    }
  }

  // Delete equipment
  static Future<bool> deleteEquipment(String equipmentId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/driver/equipment/$equipmentId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${ApiService.authToken}',
        },
      );

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('Error deleting equipment: $e');
      return false;
    }
  }

  // Get equipment completion percentage
  static double getCompletionPercentage(
    List<DeliveryEquipment> equipment,
    List<EquipmentType> types,
  ) {
    final requiredTypes = types.where((type) => type.isRequired).toList();
    if (requiredTypes.isEmpty) return 100.0;

    final ownedRequiredCount = requiredTypes
        .where(
          (type) =>
              equipment.any((eq) => eq.type == type.id && eq.status == 'owned'),
        )
        .length;

    return (ownedRequiredCount / requiredTypes.length) * 100;
  }
}
