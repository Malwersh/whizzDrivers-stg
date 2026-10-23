import 'package:flutter/material.dart';
import '../models/active_order_model.dart';
import 'order_status_timeline.dart';

/// Shared trip palette: blue actions, yellow emphasis, neutral surfaces.
class TripStyle {
  static const ink = Color(0xFF00296B);
  static const blue = Color(0xFF00509D);
  static const yellow = Color(0xFFFDC500);
  static const background = Color(0xFFF4F6FA);
  static const muted = Color(0xFF58677B);
  static bool canUnassign(ActiveOrder order) =>
      [
        'assigned',
        'accepted',
        'heading_to_store',
        'at_store',
        'arrived_at_store'
      ].contains(order.status) &&
      order.pickedUpAt == null;
  static String stage(String status) => switch (status) {
        'assigned' || 'accepted' => 'جاهز للانطلاق',
        'heading_to_store' => 'في الطريق إلى المطعم',
        'at_store' || 'arrived_at_store' => 'في المطعم • استلام الطلب',
        'picked_up' || 'heading_to_customer' => 'توصيل الطلب إلى الزبون',
        'at_customer' || 'arrived_at_customer' => 'وصلت إلى الزبون',
        'delivered' || 'completed' => 'اكتمل التسليم',
        _ => 'متابعة الطلب',
      };
}

class ActiveTripSummary extends StatelessWidget {
  const ActiveTripSummary(
      {super.key, required this.order, required this.action, this.onUnassign});
  final ActiveOrder order;
  final Widget action;
  final VoidCallback? onUnassign;

  Widget _card(Widget child) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE3E9F1))),
        child: child,
      );
  Widget _stop(IconData icon, String label, String title, String address) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: const Color(0xFFEDF3FA),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: TripStyle.blue, size: 22)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: TripStyle.muted)),
          const SizedBox(height: 4),
          Text(title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: TripStyle.ink)),
          if (address.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(address,
                style: const TextStyle(color: TripStyle.muted, height: 1.6))
          ],
        ])),
      ]);

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Column(children: [
        Expanded(
            child: ListView(
                padding: const EdgeInsets.all(20),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
              Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      color: TripStyle.ink,
                      borderRadius: BorderRadius.circular(22)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color: TripStyle.yellow,
                                  borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.delivery_dining,
                                  color: TripStyle.ink)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text(TripStyle.stage(order.status),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 19,
                                      fontWeight: FontWeight.bold)))
                        ]),
                        const SizedBox(height: 16),
                        Text(
                            'رقم الطلب ${order.orderNumber ?? order.shortOrderId}',
                            style: const TextStyle(
                                color: Color(0xFFD8E4F2), fontSize: 13)),
                      ])),
              const SizedBox(height: 16),
              _card(Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('مسار الرحلة',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: TripStyle.ink,
                            fontSize: 16)),
                    const SizedBox(height: 20),
                    _stop(
                        Icons.storefront_outlined,
                        'نقطة الاستلام',
                        order.restaurantName.trim().isEmpty
                            ? 'المطعم'
                            : order.restaurantName,
                        order.restaurantAddress),
                    const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider(height: 1)),
                    _stop(Icons.location_on_outlined, 'نقطة التسليم',
                        order.customerName, order.customerAddress),
                  ])),
              const SizedBox(height: 16),
              _card(Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      const Icon(Icons.payments_outlined,
                          color: TripStyle.blue),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(
                              order.isCashPayment
                                  ? 'التحصيل عند التسليم'
                                  : 'قيمة الطلب',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: TripStyle.ink)))
                    ]),
                    const SizedBox(height: 12),
                    Text(
                        '${(order.total ?? order.totalAmount).toStringAsFixed(0)} د.ع',
                        style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: TripStyle.ink)),
                    Text(
                        order.isCashPayment
                            ? 'دفع نقدي • يُستلم من الزبون عند التسليم'
                            : 'الدفع بالبطاقة',
                        style: const TextStyle(color: TripStyle.muted)),
                    const SizedBox(height: 12),
                    Text(
                        '${order.items.length} أصناف • ${order.items.fold<int>(0, (sum, item) => sum + item.quantity)} قطع',
                        style: const TextStyle(color: TripStyle.muted)),
                  ])),
              const SizedBox(height: 16),
              _card(ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                shape: const Border(),
                collapsedShape: const Border(),
                iconColor: TripStyle.blue,
                title: const Text('مراحل الرحلة',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: TripStyle.ink)),
                subtitle: Text(TripStyle.stage(order.status),
                    style: const TextStyle(color: TripStyle.muted)),
                children: [OrderStatusTimeline(currentStatus: order.status)],
              )),
              if (TripStyle.canUnassign(order)) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                    onPressed: onUnassign,
                    icon: const Icon(Icons.support_agent_outlined),
                    label: const Text('أحتاج مساعدة / الاعتذار عن التوصيل'),
                    style: TextButton.styleFrom(
                        foregroundColor: TripStyle.blue,
                        minimumSize: const Size(48, 48))),
              ],
            ])),
        Container(
            decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE3E9F1)))),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
            child: SafeArea(top: false, child: action)),
      ]));
}
