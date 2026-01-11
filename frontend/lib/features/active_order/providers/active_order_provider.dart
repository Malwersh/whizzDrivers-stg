import 'package:flutter/foundation.dart';
import '../models/active_order_model.dart';
import '../services/active_order_service.dart';

/// Provider لإدارة حالة الطلب النشط
class ActiveOrderProvider extends ChangeNotifier {
  final ActiveOrderService _service;

  ActiveOrder? _currentOrder;
  bool _isLoading = false;
  String? _error;

  ActiveOrderProvider(this._service);

  // Getters
  ActiveOrder? get currentOrder => _currentOrder;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasActiveOrder => _currentOrder != null;

  /// جلب الطلب النشط من السيرفر
  Future<void> fetchActiveOrder() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentOrder = await _service.getActiveOrder();
      _error = null;
    } catch (e) {
      _error = e.toString();
      _currentOrder = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// جلب طلب معين بالـ ID
  Future<void> fetchOrderById(String orderId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentOrder = await _service.getOrderById(orderId);
      _error = null;
    } catch (e) {
      _error = e.toString();
      _currentOrder = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// تعيين الطلب الحالي (للاستخدام بعد القبول مباشرة)
  void setCurrentOrder(ActiveOrder order) {
    _currentOrder = order;
    _error = null;
    notifyListeners();
  }

  /// تحديث حالة الطلب محلياً (بدون استدعاء API)
  void updateOrderStatus(String newStatus) {
    if (_currentOrder != null) {
      _currentOrder = _currentOrder!.copyWith(status: newStatus);
      notifyListeners();
    }
  }

  /// تحديث الطلب بالكامل
  void updateOrder(ActiveOrder updatedOrder) {
    _currentOrder = updatedOrder;
    notifyListeners();
  }

  /// الوصول للمطعم
  Future<bool> arriveAtStore() async {
    if (_currentOrder == null) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedOrder =
          await _service.arriveAtStore(_currentOrder!.orderId);
      _currentOrder = updatedOrder;
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// استلام الطلب
  Future<bool> pickupOrder() async {
    if (_currentOrder == null) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedOrder = await _service.pickupOrder(_currentOrder!.orderId);
      _currentOrder = updatedOrder;
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// بدء التوجه للعميل (بعد استلام الطلب من المطعم)
  Future<bool> startHeadingToCustomer() async {
    if (_currentOrder == null) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedOrder =
          await _service.startHeadingToCustomer(_currentOrder!.orderId);
      _currentOrder = updatedOrder;
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// الوصول للعميل
  Future<bool> arriveAtCustomer() async {
    if (_currentOrder == null) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedOrder =
          await _service.arriveAtCustomer(_currentOrder!.orderId);
      _currentOrder = updatedOrder;
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// تسليم الطلب
  Future<Map<String, dynamic>?> deliverOrder({
    double? cashCollected,
    String? deliveryNotes,
  }) async {
    if (_currentOrder == null) return null;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _service.deliverOrder(
        _currentOrder!.orderId,
        cashCollected: cashCollected,
        deliveryNotes: deliveryNotes,
      );

      _currentOrder = result['order'] as ActiveOrder;
      _error = null;
      _isLoading = false;
      notifyListeners();

      return result;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// الإبلاغ عن مشكلة في المطعم
  Future<bool> reportStoreIssue({
    required String issueType,
    String? notes,
  }) async {
    if (_currentOrder == null) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _service.reportStoreIssue(
        _currentOrder!.orderId,
        issueType: issueType,
        notes: notes,
      );
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// الإبلاغ عن عدم توفر العميل
  Future<bool> reportCustomerUnreachable() async {
    if (_currentOrder == null) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _service.reportCustomerUnreachable(_currentOrder!.orderId);
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// إلغاء الطلب من قبل السائق
  Future<bool> cancelOrderByDriver({
    required String reason,
    String? notes,
  }) async {
    if (_currentOrder == null) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _service.cancelOrderByDriver(
        _currentOrder!.orderId,
        reason: reason,
        notes: notes,
      );

      // بعد الإلغاء، نمسح الطلب النشط
      _currentOrder = null;
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// مسح الطلب النشط (بعد التسليم أو الإلغاء)
  void clearOrder() {
    _currentOrder = null;
    _error = null;
    notifyListeners();
  }

  /// مسح رسالة الخطأ
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// إعادة المحاولة (في حالة فشل جلب البيانات)
  Future<void> retry() async {
    await fetchActiveOrder();
  }
}
