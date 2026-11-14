import '../../models/trip_model.dart';

class EarningsSummary {
  EarningsSummary(List<Trip> input)
      : trips = {for (final trip in input) trip.orderId: trip}
            .values
            .where((t) => t.status == TripStatus.completed)
            .toList()
          ..sort((a, b) => (b.activityDate ?? DateTime(1970))
              .compareTo(a.activityDate ?? DateTime(1970)));
  final List<Trip> trips;
  List<Trip> get confirmed => trips
      .where((t) =>
          t.earningsState == 'CONFIRMED' &&
          t.driverEarnings != null &&
          t.driverEarnings!.isFinite &&
          t.driverEarnings! >= 0)
      .toList();
  int get unconfirmedCount => trips.length - confirmed.length;
  double get total => confirmed.fold(0, (sum, t) => sum + t.driverEarnings!);
  bool get hasBreakdown =>
      confirmed.isNotEmpty &&
      confirmed.every((t) =>
          t.driverBaseEarnings != null &&
          t.driverBaseEarnings!.isFinite &&
          t.driverBaseEarnings! >= 0 &&
          t.tip.isFinite &&
          t.tip >= 0 &&
          (t.driverBaseEarnings! + t.tip - t.driverEarnings!).abs() < .001);
  double get base => confirmed.fold(0, (sum, t) => sum + t.driverBaseEarnings!);
  double get tips => confirmed.fold(0, (sum, t) => sum + t.tip);
  EarningsSummary onDay(DateTime day) => EarningsSummary(trips.where((t) {
        final d = t.activityDate;
        return d != null &&
            d.year == day.year &&
            d.month == day.month &&
            d.day == day.day;
      }).toList());
}
