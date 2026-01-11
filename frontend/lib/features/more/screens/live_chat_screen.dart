import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/app_colors.dart';
import '../../../models/driver_profile.dart';
import '../../../services/wizzcentral_support_chat_service.dart';
import '../../../widgets/gradient_border_container.dart';

class LiveChatScreen extends ConsumerStatefulWidget {
  const LiveChatScreen({super.key});

  @override
  ConsumerState<LiveChatScreen> createState() => _LiveChatScreenState();
}

class _LiveChatScreenState extends ConsumerState<LiveChatScreen> {
  final WizzCentralSupportChatService _chatService =
      WizzCentralSupportChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  
  DriverProfile? _driverProfile;
  bool _isLoading = true;
  bool _isConnected = false;
  bool _isSending = false;
  String _connectionStatus = 'Initializing...';

  @override
  void initState() {
    super.initState();
    debugPrint('🎯 WIZZCENTRAL LIVE CHAT SCREEN: Initializing...');
    _loadDriverProfile();
    _initializeChat();
  }

  @override
  void dispose() {
    _chatService.disconnect();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    // Listen to connection status
    _chatService.connectionStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          _isConnected = status == 'connected';
          _connectionStatus = _getStatusText(status);
        });
        debugPrint('🔌 Connection status changed: $status');
      }
    });

    // Listen to incoming messages
    _chatService.messageStream.listen((messageData) {
      if (mounted && messageData['content'] != null) {
        setState(() {
          _messages.add(
            ChatMessage(
              id:
                  messageData['id'] ??
                  DateTime.now().millisecondsSinceEpoch.toString(),
              content: messageData['content'],
              isFromUser: messageData['isFromDriver'] ?? false,
              timestamp:
                  DateTime.tryParse(messageData['timestamp'] ?? '') ??
                  DateTime.now(),
            ),
          );
        });
        _scrollToBottom();
        debugPrint('📨 Received message: ${messageData['content']}');
      }
    });
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'disconnected':
        return 'غير متصل';
      case 'connecting':
        return 'جاري الاتصال...';
      case 'connected':
        return 'متصل';
      case 'reconnecting':
        return 'إعادة الاتصال...';
      case 'http_bridge':
        return 'متصل (HTTP)';
      case 'error':
        return 'خطأ في الاتصال';
      case 'initializing':
        return 'جاري التهيئة...';
      default:
        return status;
    }
  }

  Future<void> _loadDriverProfile() async {
    try {
      // Create default driver profile for testing (auth provider removed)
      _driverProfile = DriverProfile(
        id: 'test_driver_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Test Driver',
        phone: '+964 770 123 4567',
        email: 'testdriver@wizzapp.co',
        city: 'Baghdad',
        vehicleType: 'Car',
        licenseNumber: 'TL12345',
        nationalId: 'NID123456789',
        rating: 4.5,
        totalDeliveries: 25,
        joinDate: DateTime.now().subtract(const Duration(days: 30)),
        status: 'active',
        isVerified: true,
        preferredLanguage: 'ar',
      );

      // Initialize chat service with driver info
      if (_driverProfile != null) {
        final success = await _chatService.initializeSupportChat(
          driverId: _driverProfile!.id,
          driverName: _driverProfile!.name,
          driverPhone: _driverProfile!.phone,
        );

        if (success) {
          // Send initial welcome message
          final welcomeMessage =
              'مرحباً، أنا ${_driverProfile!.name} من مدينة ${_driverProfile!.city}. أحتاج للمساعدة.';
          await _chatService.sendSupportMessage(welcomeMessage);
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading driver profile: $e');
      // Create fallback profile even on error
      _driverProfile = DriverProfile(
        id: 'fallback_driver_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Driver',
        phone: '+964 770 000 0000',
        email: 'driver@wizzapp.co',
        city: 'Baghdad',
        vehicleType: 'Car',
        licenseNumber: 'FL12345',
        nationalId: 'NID000000000',
        rating: 4.0,
        totalDeliveries: 0,
        joinDate: DateTime.now(),
        status: 'active',
        isVerified: false,
        preferredLanguage: 'ar',
      );

      // Initialize chat service even with fallback
      if (_driverProfile != null) {
        await _chatService.initializeSupportChat(
          driverId: _driverProfile!.id,
          driverName: _driverProfile!.name,
          driverPhone: _driverProfile!.phone,
        );
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
      _messages.add(
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: message,
          isFromUser: true,
          timestamp: DateTime.now(),
        ),
      );
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      await _chatService.sendSupportMessage(message);
      debugPrint('📤 Message sent successfully: $message');
    } catch (e) {
      debugPrint('❌ Failed to send message: $e');

      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في إرسال الرسالة: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text(
                    'جاري تحميل الدردشة...',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Connection status banner
                if (!_isConnected)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    color: _connectionStatus.contains('خطأ')
                        ? Colors.red.shade100
                        : Colors.orange.shade100,
                    child: Row(
                      children: [
                        Icon(
                          _connectionStatus.contains('خطأ')
                              ? Icons.error_outline
                              : Icons.wifi_off,
                          color: _connectionStatus.contains('خطأ')
                              ? Colors.red
                              : Colors.orange,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _connectionStatus,
                          style: TextStyle(
                            color: _connectionStatus.contains('خطأ')
                                ? Colors.red.shade700
                                : Colors.orange.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Messages area
                Expanded(
                  child: _messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 64,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'ابدأ محادثة مع فريق الدعم',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'نحن هنا لمساعدتك في أي استفسار',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            return _buildMessageBubble(message);
                          },
                        ),
                ),

                // Message input area
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade200,
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: 'اكتب رسالتك هنا...',
                            hintStyle: TextStyle(color: Colors.grey.shade500),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: _isSending ? null : _sendMessage,
                          icon: _isSending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: message.isFromUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!message.isFromUser) ...[
            GradientBorderContainer.circular(
              borderWidth: 2,
              child: CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: const Icon(
                  Icons.support_agent,
                  size: 16,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isFromUser
                    ? AppColors.primary
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomLeft: message.isFromUser
                      ? const Radius.circular(20)
                      : const Radius.circular(4),
                  bottomRight: message.isFromUser
                      ? const Radius.circular(4)
                      : const Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      color: message.isFromUser ? Colors.white : Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      color: message.isFromUser
                          ? Colors.white70
                          : Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (message.isFromUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: const Icon(
                Icons.person,
                size: 16,
                color: AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${dateTime.day}/${dateTime.month}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

class ChatMessage {
  final String id;
  final String content;
  final bool isFromUser;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.content,
    required this.isFromUser,
    required this.timestamp,
  });
}
