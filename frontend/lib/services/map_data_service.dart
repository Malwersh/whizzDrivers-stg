import 'dart:async';
import 'dart:io';
import 'map_data_failure.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/map_data.dart';
import '../providers/driver_auth_provider.dart';
import '../config/environment.dart';

/// Service for fetching map data from backend API
class MapDataService {
  static const String _baseUrl = Environment.apiBaseUrl;

  /// Fetch map data for driver's current location
  ///
  /// Returns stores, regions, and hot stores info
  static Future<MapDataResponse> fetchMapData({
    required double lat,
    required double lng,
    http.Client? client,
    Future<String?> Function()? tokenProvider,
  }) async {
    try {
      // 🔐 Get authentication token
      final authToken =
          await (tokenProvider ?? DriverAuthHelper.getCurrentAccessToken)();

      if (authToken == null) {
        throw const MapDataFailure(MapDataFailureKind.authentication);
      }

      final uri = Uri.parse('$_baseUrl/driver/map-data').replace(
        queryParameters: {
          'lat': lat.toString(),
          'lng': lng.toString(),
        },
      );

      debugPrint('🗺️ Fetching map data: $uri');
      debugPrint('🔑 Auth token length: ${authToken.length}');

      final response = await (client?.get ?? http.get)(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Map request timed out');
        },
      );

      debugPrint('📥 Map data response status: ${response.statusCode}');

      Map<String, dynamic> data;
      try {
        data = Map<String, dynamic>.from(json.decode(response.body));
      } catch (_) {
        throw const MapDataFailure(MapDataFailureKind.server);
      }
      final failure = MapDataFailure.fromResponse(response.statusCode, data);
      if (failure != null) throw failure;
      if (data['success'] != true) {
        throw const MapDataFailure(MapDataFailureKind.server);
      }
      return MapDataResponse.fromJson(data);
    } on MapDataFailure {
      rethrow;
    } on TimeoutException {
      throw const MapDataFailure(MapDataFailureKind.connection);
    } on SocketException {
      throw const MapDataFailure(MapDataFailureKind.connection);
    } on http.ClientException {
      throw const MapDataFailure(MapDataFailureKind.connection);
    } catch (_) {
      throw const MapDataFailure(MapDataFailureKind.server);
    }
  }
}
