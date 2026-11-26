import '../../models/trip_model.dart';
import '../../services/trips_service.dart';
import 'earnings_summary.dart';

typedef EarningsPageLoader = Future<Map<String, dynamic>> Function(
    {String? nextToken, String? status, DateTime? from, DateTime? to});

class EarningsService {
  EarningsService(
      {EarningsPageLoader? loadPage, Future<String?> Function()? token})
      : token = token ??
            (() async => (await TripsService.buildHeadersForProtectedRequest())[
                'Authorization']),
        loadPage = loadPage ??
            ((
                    {String? nextToken,
                    String? status,
                    DateTime? from,
                    DateTime? to}) =>
                TripsService.fetchDriverTrips(
                    limit: 100,
                    nextToken: nextToken,
                    status: status,
                    from: from,
                    to: to));
  final EarningsPageLoader loadPage;
  final Future<String?> Function() token;
  Future<EarningsSummary> load(DateTime from, DateTime to,
      {bool Function()? isCurrent}) async {
    final pinnedToken = await token();
    if (pinnedToken == null || pinnedToken.isEmpty)
      throw StateError('Authentication required');
    final rows = <Trip>[];
    final seen = <String>{};
    String? cursor;
    final started = DateTime.now();
    for (var page = 0; page < 100; page++) {
      if (isCurrent?.call() == false) throw StateError('Selection changed');
      if (await token() != pinnedToken) throw StateError('Account changed');
      if (DateTime.now().difference(started) > const Duration(seconds: 60))
        throw StateError('Incomplete period');
      final response = await loadPage(
          nextToken: cursor, status: 'completed', from: from, to: to);
      if (isCurrent?.call() == false) throw StateError('Selection changed');
      if (await token() != pinnedToken) throw StateError('Account changed');
      if (response['success'] != true) throw StateError('Incomplete period');
      rows.addAll((response['trips'] as List<Trip>).where((t) {
        final d = t.activityDate;
        return d != null && !d.isBefore(from) && !d.isAfter(to);
      }));
      if (response['hasMore'] != true) return EarningsSummary(rows);
      cursor = response['nextToken'] as String?;
      if (cursor == null || cursor.isEmpty || !seen.add(cursor))
        throw StateError('Incomplete period');
    }
    throw StateError('Incomplete period');
  }
}
