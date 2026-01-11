import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/active_order/models/active_order_model.dart';
import '../../features/active_order/services/active_order_service.dart';

/// State للطلب النشط
class ActiveOrderState {
  final ActiveOrder? order;
  final bool isLoading;
  final String? error;

  ActiveOrderState({
    this.order,
    this.isLoading = false,
    this.error,
  });

  ActiveOrderState copyWith({
    ActiveOrder? order,
    bool? isLoading,
    String? error,
  }) {
    return ActiveOrderState(
      order: order ?? this.order,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Provider للطلب النشط
class ActiveOrderNotifier extends StateNotifier<ActiveOrderState> {
  final ActiveOrderService _service;

  ActiveOrderNotifier(this._service) : super(ActiveOrderState());

  /// جلب الطلب النشط
  Future<void> fetchActiveOrder() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final order = await _service.getActiveOrder();
      state = ActiveOrderState(order: order, isLoading: false);
    } catch (e) {
      state = ActiveOrderState(
        order: null,
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// جلب طلب معين بالـ ID
  Future<void> fetchOrderById(String orderId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final order = await _service.getOrderById(orderId);
      state = ActiveOrderState(order: order, isLoading: false);
    } catch (e) {
      state = ActiveOrderState(
        order: null,
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// تعيين الطلب الحالي
  void setOrder(ActiveOrder order) {
    state = ActiveOrderState(order: order, isLoading: false);
  }

  /// تحديث حالة الطلب محلياً
  void updateStatus(String newStatus) {
    if (state.order != null) {
      state = state.copyWith(
        order: state.order!.copyWith(status: newStatus),
      );
    }
  }

  /// بدء التوجه للمطعم (عند النقر على زر "انطلق")
  Future<bool> startHeadingToStore() async {
    if (state.order == null) return false;

    state = state.copyWith(isLoading: true);

    try {
      final updatedOrder = await _service.startHeadingToStore(state.order!.orderId);
      state = ActiveOrderState(order: updatedOrder, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// الوصول للمطعم (عند سحب السلايد)
  Future<bool> arriveAtStore() async {
    print('🔍 arriveAtStore Provider: Starting...');
    print('🔍 arriveAtStore Provider: state.order = ${state.order?.orderId}');
    
    if (state.order == null) {
      print('❌ arriveAtStore Provider: state.order is NULL! Cannot proceed.');
      return false;
    }

    print('✅ arriveAtStore Provider: Order exists, calling API...');
    state = state.copyWith(isLoading: true);

    try {
      final updatedOrder = await _service.arriveAtStore(state.order!.orderId);
      print('✅ arriveAtStore Provider: API Success! Updated to ${updatedOrder.status}');
      state = ActiveOrderState(order: updatedOrder, isLoading: false);
      return true;
    } catch (e) {
      print('❌ arriveAtStore Provider: API Failed! Error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// تحديث الطلب الحالي في الـ state (مهم عند استعادة الحالة بعد hot restart)
  void updateOrder(ActiveOrder order) {
    print('📥 updateOrder Provider: Updating with orderId ${order.orderId}, status: ${order.status}');
    state = ActiveOrderState(order: order, isLoading: false);
    print('✅ updateOrder Provider: State updated successfully');
  }

  /// استلام الطلب
  Future<bool> pickupOrder() async {
    if (state.order == null) return false;

    state = state.copyWith(isLoading: true);

    try {
      final updatedOrder = await _service.pickupOrder(state.order!.orderId);
      state = ActiveOrderState(order: updatedOrder, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// بدء التوجه للعميل (بعد استلام الطلب من المطعم)
  Future<bool> startHeadingToCustomer() async {
    if (state.order == null) return false;

    state = state.copyWith(isLoading: true);

    try {
      final updatedOrder =
          await _service.startHeadingToCustomer(state.order!.orderId);
      state = ActiveOrderState(order: updatedOrder, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// الوصول للعميل
  Future<bool> arriveAtCustomer() async {
    if (state.order == null) return false;

    state = state.copyWith(isLoading: true);

    try {
      final updatedOrder =
          await _service.arriveAtCustomer(state.order!.orderId);
      state = ActiveOrderState(order: updatedOrder, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// تسليم الطلب
  Future<Map<String, dynamic>?> deliverOrder({
    double? cashCollected,
    String? deliveryNotes,
  }) async {
    if (state.order == null) return null;

    state = state.copyWith(isLoading: true);

    try {
      final result = await _service.deliverOrder(
        state.order!.orderId,
        cashCollected: cashCollected,
        deliveryNotes: deliveryNotes,
      );

      // مسح الطلب بعد التسليم بنجاح
      state = ActiveOrderState(isLoading: false);

      return result;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  /// إلغاء الطلب من قبل السائق
  Future<bool> cancelOrderByDriver({
    required String reason,
    String? notes,
  }) async {
    if (state.order == null) return false;

    state = state.copyWith(isLoading: true);

    try {
      await _service.cancelOrderByDriver(
        state.order!.orderId,
        reason: reason,
        notes: notes,
      );

      // مسح الطلب بعد الإلغاء بنجاح
      state = ActiveOrderState(isLoading: false);

      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// مسح الطلب
  void clearOrder() {
    state = ActiveOrderState();
  }

  /// مسح الخطأ
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider للـ ActiveOrderService
final activeOrderServiceProvider = Provider<ActiveOrderService>((ref) {
  return ActiveOrderService();
});

/// Provider الرئيسي للطلب النشط
final activeOrderProvider =
    StateNotifierProvider<ActiveOrderNotifier, ActiveOrderState>((ref) {
  final service = ref.watch(activeOrderServiceProvider);
  return ActiveOrderNotifier(service);
});

/// Helper provider للتحقق من وجود طلب نشط
final hasActiveOrderProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(activeOrderServiceProvider);
  return await service.hasActiveOrder();
});
