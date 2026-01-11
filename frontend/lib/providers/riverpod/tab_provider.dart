import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global selected tab index for the main bottom navigation.
///
/// This allows external events (e.g., notification taps) to switch tabs even
/// when the HomePage widget is already alive and query params haven't changed.
final selectedTabProvider = StateProvider<int>((ref) => 0);
