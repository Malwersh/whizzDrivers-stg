import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/environment.dart';

class OrdersAPIService {
  static final OrdersAPIService _instance = OrdersAPIService._internal();
  factory OrdersAPIService() => _instance;
  OrdersAPIService._internal();

  // Use orders-specific API
  static String get _baseUrl => Environment.ordersApiBaseUrl;
  static final http.Client _client = http.Client();

  Map<String, String> get _headers => {
    HttpHeaders.acceptHeader: 'application/json',
    HttpHeaders.contentTypeHeader: 'application/json',
  };

  Uri _uri(String path) {
    return Uri.parse('$_baseUrl$path');
  }

  /// Query orders from orders API (no auth required for guest orders)
  Future<Map<String, dynamic>?> queryOrders({
    List<String>? status,
    String? assignedDriverId,
    int? limit,
  }) async {
    try {
      debugPrint('OrdersAPI - Querying orders with status: $status');
      
      final queryParams = <String, String>{};
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status.join(',');
      }
      if (assignedDriverId != null) {
        queryParams['assignedDriverId'] = assignedDriverId;
      }
      if (limit != null) {
        queryParams['limit'] = limit.toString();
      }
      
      final uri = _uri('/orders').replace(queryParameters: queryParams);
      final resp = await _client.get(uri, headers: _headers);
      
      debugPrint('OrdersAPI - GET /orders -> ${resp.statusCode}');
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body);
      }
      return null;
    } catch (e) {
      debugPrint('OrdersAPI - Error queryOrders: $e');
      return null;
    }
  }

  /// Update order status
  Future<bool> updateOrder({
    required String orderId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      debugPrint('OrdersAPI - Updating order: $orderId');
      
      final resp = await _client.patch(
        _uri('/orders/$orderId'),
        headers: _headers,
        body: jsonEncode(updates),
      );
      
      debugPrint('OrdersAPI - PATCH /orders/$orderId -> ${resp.statusCode}');
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (e) {
      debugPrint('OrdersAPI - Error updateOrder: $e');
      return false;
    }
  }

  /// Add driver to rejected list
  Future<bool> addDriverToRejectedList({
    required String orderId,
    required String driverId,
  }) async {
    try {
      debugPrint('OrdersAPI - Adding driver $driverId to rejected list for order $orderId');
      
      final resp = await _client.post(
        _uri('/orders/$orderId/reject'),
        headers: _headers,
        body: jsonEncode({'driverId': driverId}),
      );
      
      debugPrint('OrdersAPI - POST /orders/$orderId/reject -> ${resp.statusCode}');
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (e) {
      debugPrint('OrdersAPI - Error addDriverToRejectedList: $e');
      return false;
    }
  }
}