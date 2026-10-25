import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Route/notification IDs remain unchanged when a bottom-bar item is removed.
class DriverTabs {
  static const home = 0;
  static const trips = 1;
  static const wallet = 2;
  static const notifications = 4;
  static const more = 5;
  static const visible = [home, trips, wallet, notifications, more];

  // Old earnings-tab links now lead to More, where earnings is available.
  static int normalize(int id) => id == 3
      ? more
      : visible.contains(id)
          ? id
          : home;
  static int position(int id) => visible.indexOf(normalize(id));
  static int idAt(int position) => visible[position];
  static String name(int id) => const {
        home: 'home',
        trips: 'trips',
        wallet: 'wallet',
        notifications: 'notifications',
        more: 'more',
      }[normalize(id)]!;
}

final selectedTabProvider = StateProvider<int>((ref) => DriverTabs.home);
