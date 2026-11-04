import 'package:flutter/material.dart';
import '../features/more/screens/live_chat_screen.dart';

/// Compatibility entry point; identity always comes from the signed-in session.
class DriverSupportChatScreen extends StatelessWidget {
  final String driverId;
  final String? driverName, initialTopic;
  const DriverSupportChatScreen(
      {super.key, required this.driverId, this.driverName, this.initialTopic});
  @override
  Widget build(BuildContext context) => const LiveChatScreen();
}
