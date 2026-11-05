import 'package:flutter/material.dart';
import '../features/more/screens/live_chat_screen.dart';

/// Compatibility entry for earnings cards and quick support. Caller-supplied
/// profile labels never establish identity; LiveChatScreen reads live Cognito.
class DriverSupportChatScreen extends StatelessWidget {
  const DriverSupportChatScreen(
      {super.key, required this.driverId, this.driverName, this.initialTopic});
  final String driverId;
  final String? driverName;
  final String? initialTopic;
  @override
  Widget build(BuildContext context) =>
      LiveChatScreen(initialTopic: initialTopic);
}
