import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;
import '../../models/trip_model.dart';
import '../active_order/widgets/active_trip_summary.dart';

String tripMoney(double? n) =>
    n == null ? 'غير متاح' : '${NumberFormat('#,##0.###', 'en').format(n)} د.ع';
Color tripStatusColor(TripStatus s) => switch (s) {
      TripStatus.completed => const Color(0xFF176B43),
      TripStatus.cancelled => const Color(0xFFA63131),
      _ => TripStyle.blue
    };

class TripStatusBadge extends StatelessWidget {
  const TripStatusBadge({super.key, required this.trip});
  final Trip trip;
  @override
  Widget build(BuildContext context) {
    final color = tripStatusColor(trip.status);
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(20)),
        child: Text(trip.getStatusText(),
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w600)));
  }
}

Widget tripPanel(Widget child) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0E7F0))),
    child: child);
