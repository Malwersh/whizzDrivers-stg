import 'package:flutter/material.dart';
import '../models/active_order_model.dart';
import 'active_trip_summary.dart';

enum DriverTripHelpAction {
  callStore,
  callCustomer,
  items,
  reportPickup,
  unassign,
  unableToDeliver
}

class DriverTripHelp extends StatelessWidget {
  const DriverTripHelp(
      {super.key, required this.order, this.allowUnableToDeliver = false});
  final bool allowUnableToDeliver;
  final ActiveOrder order;
  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
                child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            const Expanded(
                                child: Text('مساعدة في هذه الرحلة',
                                    style: TextStyle(
                                        fontSize: 21,
                                        fontWeight: FontWeight.bold,
                                        color: TripStyle.ink))),
                            IconButton(
                                tooltip: 'إغلاق',
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close))
                          ]),
                          const Text('اختر الإجراء المناسب للطلب الحالي',
                              style: TextStyle(color: TripStyle.muted)),
                          const SizedBox(height: 16),
                          if (order.restaurantPhone?.trim().isNotEmpty == true)
                            _option(
                                context,
                                Icons.storefront_outlined,
                                'الاتصال بالمتجر',
                                'للاستفسار عن الاستلام',
                                DriverTripHelpAction.callStore),
                          if (order.customerPhone.trim().isNotEmpty)
                            _option(
                                context,
                                Icons.call_outlined,
                                'الاتصال بالزبون',
                                'للتواصل بشأن هذا الطلب',
                                DriverTripHelpAction.callCustomer),
                          _option(
                              context,
                              Icons.receipt_long_outlined,
                              'تفاصيل الأصناف',
                              'عرض محتويات الطلب',
                              DriverTripHelpAction.items),
                          if (TripStyle.canUnassign(order))
                            _option(
                                context,
                                Icons.report_outlined,
                                'الإبلاغ عن مشكلة في الاستلام',
                                'تسجيل مشكلة المتجر أو التأخير',
                                DriverTripHelpAction.reportPickup),
                          if (TripStyle.canUnassign(order)) ...[
                            const Divider(height: 24),
                            _option(
                                context,
                                Icons.person_remove_outlined,
                                'الاعتذار عن التوصيل',
                                'قبل استلام الطعام • البحث عن سائق بديل',
                                DriverTripHelpAction.unassign)
                          ],
                          if (allowUnableToDeliver &&
                              order.financialAssignment != null &&
                              !TripStyle.canUnassign(order)) ...[
                            const Divider(height: 24),
                            _option(
                                context,
                                Icons.help_outline,
                                'تعذّر إكمال التوصيل',
                                'الحصول على المساعدة لإكمال الرحلة',
                                DriverTripHelpAction.unableToDeliver),
                          ],
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('العودة إلى الطلب'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: TripStyle.blue,
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ]))),
          )));
  Widget _option(BuildContext context, IconData icon, String title,
          String subtitle, DriverTripHelpAction action) =>
      ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 5),
        leading: CircleAvatar(
            backgroundColor: const Color(0xFFEDF3FA),
            child: Icon(icon, color: TripStyle.blue)),
        title: Text(title,
            style: const TextStyle(
                color: TripStyle.ink, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style: const TextStyle(color: TripStyle.muted, fontSize: 12)),
        trailing: const Icon(Icons.chevron_left, color: TripStyle.muted),
        onTap: () => Navigator.pop(context, action),
      );
}
