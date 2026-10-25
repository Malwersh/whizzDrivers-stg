import 'package:flutter_test/flutter_test.dart';
import 'package:wizz_driver/models/driver_performance_snapshot.dart';

void main() {
  test('missing record defaults never look like measured zero', () {
    final s = DriverPerformanceSnapshot({'acceptanceRate': 0, 'totalTrips': 0});
    expect(s.rate('acceptanceRate'), isNull);
    expect(s.count('totalTrips'), isNull);
  });
  test('legacy ratio without explicit status remains unavailable', () {
    expect(
        DriverPerformanceSnapshot(
                {'acceptanceRate': .75, 'updatedAt': '2026-10-24T12:00:00Z'})
            .rate('acceptanceRate'),
        isNull);
  });
  test('confirmed zero and one are valid, malformed and out of range are not',
      () {
    for (final v in [0, 1, .75, -1, 75, double.nan, '0.75', null]) {
      final s = DriverPerformanceSnapshot({
        'acceptanceRate': v,
        'acceptanceRateStatus': 'AVAILABLE',
        'updatedAt': '2026-10-24T12:00:00Z'
      });
      expect(s.rate('acceptanceRate'),
          v is num && v.isFinite && v >= 0 && v <= 1 ? v.toDouble() : null);
    }
  });
  test('provisional and unavailable completion never become zero', () {
    for (final status in ['UNAVAILABLE', 'INSUFFICIENT_DATA']) {
      expect(
          DriverPerformanceSnapshot({
            'completionRate': 0,
            'completionRateStatus': status,
            'updatedAt': '2026-10-24T12:00:00Z'
          }).rate('completionRate'),
          isNull);
    }
  });
}
