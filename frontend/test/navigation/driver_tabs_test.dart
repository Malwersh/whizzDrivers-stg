import 'package:flutter_test/flutter_test.dart';
import 'package:wizz_driver/providers/riverpod/tab_provider.dart';

void main() {
  test(
      'five content destinations retain stable route IDs independently of bottom bar',
      () {
    expect(DriverTabs.visible, [0, 1, 2, 4, 5]);
    for (var i = 0; i < DriverTabs.visible.length; i++) {
      expect(DriverTabs.position(DriverTabs.idAt(i)), i);
    }
  });
  test('existing notification and wallet destinations retain their meaning',
      () {
    expect(DriverTabs.name(4), 'notifications');
    expect(DriverTabs.idAt(3), 4);
    expect(DriverTabs.idAt(2), 2);
    expect(DriverTabs.idAt(4), 5);
  });
  test('old earnings links go to More and invalid routes fall back to home',
      () {
    expect(DriverTabs.normalize(3), DriverTabs.more);
    expect(DriverTabs.position(3), 4);
    expect(DriverTabs.normalize(-1), DriverTabs.home);
    expect(DriverTabs.normalize(99), DriverTabs.home);
  });
}
