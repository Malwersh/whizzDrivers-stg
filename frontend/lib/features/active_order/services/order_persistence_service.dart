import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// خدمة حفظ واستعادة حالة الطلب النشط
class OrderPersistenceService {
  static const String _activeOrderKey = 'active_order';
  static const String _orderStateKey = 'order_state';
  static const String _lastUpdateKey = 'last_update';

  /// حفظ الطلب النشط محلياً
  static Future<void> saveActiveOrder({
    required String orderId,
    required String status,
    required Map<String, dynamic> orderData,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setString(_activeOrderKey, orderId);
      await prefs.setString(_orderStateKey, status);
      await prefs.setString(
        'order_data_$orderId',
        jsonEncode(orderData),
      );
      await prefs.setString(
        _lastUpdateKey,
        DateTime.now().toIso8601String(),
      );

      debugPrint('💾 Order saved locally: $orderId (status: $status)');
    } catch (e) {
      debugPrint('❌ Error saving order: $e');
    }
  }

  /// استعادة الطلب النشط
  static Future<Map<String, dynamic>?> getActiveOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final orderId = prefs.getString(_activeOrderKey);
      if (orderId == null) {
        debugPrint('ℹ️ No active order found');
        return null;
      }

      final status = prefs.getString(_orderStateKey);
      final orderDataJson = prefs.getString('order_data_$orderId');
      final lastUpdate = prefs.getString(_lastUpdateKey);

      if (orderDataJson == null) {
        debugPrint('⚠️ Order data not found for: $orderId');
        return null;
      }

      final orderData = jsonDecode(orderDataJson) as Map<String, dynamic>;

      debugPrint('📖 Active order restored: $orderId (status: $status)');

      return {
        'orderId': orderId,
        'status': status,
        'orderData': orderData,
        'lastUpdate': lastUpdate,
      };
    } catch (e) {
      debugPrint('❌ Error getting active order: $e');
      return null;
    }
  }

  /// مسح الطلب النشط
  static Future<void> clearActiveOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final orderId = prefs.getString(_activeOrderKey);
      
      await prefs.remove(_activeOrderKey);
      await prefs.remove(_orderStateKey);
      await prefs.remove(_lastUpdateKey);
      
      if (orderId != null) {
        await prefs.remove('order_data_$orderId');
      }

      debugPrint('🗑️ Active order cleared');
    } catch (e) {
      debugPrint('❌ Error clearing order: $e');
    }
  }

  /// التحقق من وجود طلب نشط
  static Future<bool> hasActiveOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_activeOrderKey);
    } catch (e) {
      debugPrint('❌ Error checking active order: $e');
      return false;
    }
  }

  /// تحديث حالة الطلب فقط
  static Future<void> updateOrderStatus(String status) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_orderStateKey, status);
      await prefs.setString(
        _lastUpdateKey,
        DateTime.now().toIso8601String(),
      );

      debugPrint('🔄 Order status updated: $status');
    } catch (e) {
      debugPrint('❌ Error updating status: $e');
    }
  }

  /// الحصول على آخر حالة محفوظة
  static Future<String?> getLastStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_orderStateKey);
    } catch (e) {
      debugPrint('❌ Error getting status: $e');
      return null;
    }
  }

  /// حفظ طابع زمني لآخر تزامن مع السيرفر
  static Future<void> saveLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'last_sync',
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      debugPrint('❌ Error saving sync time: $e');
    }
  }

  /// الحصول على وقت آخر تزامن
  static Future<DateTime?> getLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final syncTime = prefs.getString('last_sync');
      
      if (syncTime == null) return null;
      
      return DateTime.parse(syncTime);
    } catch (e) {
      debugPrint('❌ Error getting sync time: $e');
      return null;
    }
  }

  /// حفظ عمليات معلقة (للتنفيذ عند عودة الاتصال)
  static Future<void> savePendingAction({
    required String action,
    required Map<String, dynamic> data,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // الحصول على العمليات المعلقة الحالية
      final pendingJson = prefs.getString('pending_actions');
      List<dynamic> pending = [];
      
      if (pendingJson != null) {
        pending = jsonDecode(pendingJson) as List<dynamic>;
      }

      // إضافة العملية الجديدة
      pending.add({
        'action': action,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      });

      await prefs.setString('pending_actions', jsonEncode(pending));

      debugPrint('📝 Pending action saved: $action');
    } catch (e) {
      debugPrint('❌ Error saving pending action: $e');
    }
  }

  /// الحصول على العمليات المعلقة
  static Future<List<Map<String, dynamic>>> getPendingActions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingJson = prefs.getString('pending_actions');
      
      if (pendingJson == null) return [];
      
      final List<dynamic> pending = jsonDecode(pendingJson);
      return pending.map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('❌ Error getting pending actions: $e');
      return [];
    }
  }

  /// مسح العمليات المعلقة
  static Future<void> clearPendingActions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_actions');
      debugPrint('🗑️ Pending actions cleared');
    } catch (e) {
      debugPrint('❌ Error clearing pending actions: $e');
    }
  }

  /// مسح عملية معلقة محددة
  static Future<void> removePendingAction(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingJson = prefs.getString('pending_actions');
      
      if (pendingJson == null) return;
      
      List<dynamic> pending = jsonDecode(pendingJson);
      
      if (index >= 0 && index < pending.length) {
        pending.removeAt(index);
        await prefs.setString('pending_actions', jsonEncode(pending));
        debugPrint('🗑️ Pending action removed at index: $index');
      }
    } catch (e) {
      debugPrint('❌ Error removing pending action: $e');
    }
  }
}
