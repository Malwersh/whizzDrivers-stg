import 'package:flutter/material.dart';
import '../pages/driver_support_chat_screen.dart';
import '../services/unified_driver_chat_service.dart';

/// Floating Support Chat Button Widget
/// Can be added to any screen to provide quick access to support chat
class SupportChatButton extends StatefulWidget {
  final String driverId;
  final String? driverName;
  final String? phoneNumber;
  final String? quickTopic;

  const SupportChatButton({
    super.key,
    required this.driverId,
    this.driverName,
    this.phoneNumber,
    this.quickTopic,
  });

  @override
  State<SupportChatButton> createState() => _SupportChatButtonState();
}

class _SupportChatButtonState extends State<SupportChatButton>
    with SingleTickerProviderStateMixin {
  final UnifiedDriverChatService _chatService = UnifiedDriverChatService();
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  bool _hasUnreadMessages = false;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Listen for new messages to show badge
    _chatService.messageStream.listen((messageData) {
      if (mounted) {
        setState(() {
          _hasUnreadMessages = true;
          _unreadCount++;
        });
        _animateButton();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _animateButton() {
    _animationController.forward().then((_) {
      _animationController.reverse();
    });
  }

  void _openSupportChat() {
    // Clear unread count when opening chat
    setState(() {
      _hasUnreadMessages = false;
      _unreadCount = 0;
    });

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DriverSupportChatScreen(
          driverId: widget.driverId,
          driverName: widget.driverName,
          initialTopic: widget.quickTopic,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Stack(
            children: [
              FloatingActionButton(
                onPressed: _openSupportChat,
                backgroundColor: Colors.blue[600],
                heroTag: "support_chat_fab",
                child: const Icon(Icons.support_agent, color: Colors.white),
              ),

              // Unread message badge
              if (_hasUnreadMessages)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      _unreadCount > 9 ? '9+' : _unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Support Chat Card Widget
/// Can be embedded in screens like profile or help sections
class SupportChatCard extends StatelessWidget {
  final String driverId;
  final String? driverName;
  final String? phoneNumber;
  final List<String> quickTopics;

  const SupportChatCard({
    super.key,
    required this.driverId,
    this.driverName,
    this.phoneNumber,
    this.quickTopics = const [],
  });

  @override
  Widget build(BuildContext context) {
    final defaultTopics = [
      'Technical Issue',
      'Payment Problem',
      'Account Help',
      'Order Support',
      'General Question',
    ];

    final topics = quickTopics.isNotEmpty ? quickTopics : defaultTopics;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.support_agent, color: Colors.blue[600]),
                const SizedBox(width: 8),
                const Text(
                  'Need Help?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Get instant support from our team. Chat with a live agent now.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Quick topic buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: topics.map((topic) {
                return ElevatedButton(
                  onPressed: () => _openChatWithTopic(context, topic),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[50],
                    foregroundColor: Colors.blue[700],
                    elevation: 0,
                  ),
                  child: Text(topic),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Main chat button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openChatWithTopic(context, null),
                icon: const Icon(Icons.chat),
                label: const Text('Start Live Chat'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openChatWithTopic(BuildContext context, String? topic) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DriverSupportChatScreen(
          driverId: driverId,
          driverName: driverName,
          initialTopic: topic,
        ),
      ),
    );
  }
}

/// Support Chat Bottom Sheet
/// Quick access support chat as a bottom sheet
class SupportChatBottomSheet {
  static void show(
    BuildContext context, {
    required String driverId,
    String? driverName,
    String? phoneNumber,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.support_agent, color: Colors.blue[600]),
                    const SizedBox(width: 8),
                    const Text(
                      'Quick Support',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),

              // Chat interface
              Expanded(
                child: DriverSupportChatScreen(
                  driverId: driverId,
                  driverName: driverName,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
