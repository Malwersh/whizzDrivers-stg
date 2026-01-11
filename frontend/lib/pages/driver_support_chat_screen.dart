import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/unified_driver_chat_service.dart';
import '../widgets/gradient_border_container.dart';

/// Driver Support Chat Screen
/// Provides interface for drivers to chat with support agents
class DriverSupportChatScreen extends StatefulWidget {
  final String driverId;
  final String? driverName;
  final String? initialTopic;

  const DriverSupportChatScreen({
    super.key,
    required this.driverId,
    this.driverName,
    this.initialTopic,
  });

  @override
  State<DriverSupportChatScreen> createState() => _DriverSupportChatScreenState();
}

class _DriverSupportChatScreenState extends State<DriverSupportChatScreen> {
  final UnifiedDriverChatService _chatService = UnifiedDriverChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  final List<ChatMessage> _messages = [];
  bool _isConnected = false;
  bool _isLoading = true;
  String? _sessionId;
  String? _agentName;
  
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _messageSubscription;
  StreamSubscription? _sessionSubscription;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _messageSubscription?.cancel();
    _sessionSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    // Listen to connection status
    _connectionSubscription = _chatService.connectionStream.listen((connected) {
      setState(() {
        _isConnected = connected;
        if (connected && _sessionId == null) {
          _startChatSession();
        }
      });
    });

    // Listen to messages
    _messageSubscription = _chatService.messageStream.listen((messageData) {
      _handleIncomingMessage(messageData);
    });

    // Listen to session updates
    _sessionSubscription = _chatService.sessionStream.listen((sessionData) {
      _handleSessionUpdate(sessionData);
    });

    // Initialize the service
    final success = await _chatService.initialize(
      widget.driverId,
      driverName: widget.driverName,
    );

    setState(() {
      _isLoading = false;
    });

    if (!success) {
      _showErrorSnackBar('Failed to connect to support chat');
    }
  }

  Future<void> _startChatSession() async {
    final sessionId = await _chatService.startChatSession(
      topic: widget.initialTopic ?? 'Driver Support Request',
      description: 'Driver ${widget.driverId} requesting support',
    );

    if (sessionId != null) {
      setState(() {
        _sessionId = sessionId;
      });
      
      _addSystemMessage('Chat session started. An agent will be with you shortly.');
    }
  }

  void _handleIncomingMessage(Map<String, dynamic> messageData) {
    final action = messageData['action'] as String?;
    
    switch (action) {
      case 'message_received':
      case 'agent_message':
        final message = ChatMessage(
          id: messageData['messageId'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
          senderId: messageData['senderId'] as String? ?? 'agent',
          senderName: messageData['senderName'] as String? ?? 'Support Agent',
          message: messageData['message'] as String? ?? '',
          timestamp: DateTime.tryParse(messageData['timestamp'] as String? ?? '') ?? DateTime.now(),
          isFromDriver: false,
        );
        
        setState(() {
          _messages.add(message);
          if (message.senderName != 'Support Agent') {
            _agentName = message.senderName;
          }
        });
        
        _scrollToBottom();
        _vibrate();
        break;
    }
  }

  void _handleSessionUpdate(Map<String, dynamic> sessionData) {
    final action = sessionData['action'] as String?;
    
    switch (action) {
      case 'session_created':
        _sessionId = sessionData['sessionId'] as String?;
        _addSystemMessage('Chat session created. Waiting for agent...');
        break;
        
      case 'session_assigned':
        final agentName = sessionData['agentName'] as String?;
        if (agentName != null) {
          _agentName = agentName;
          _addSystemMessage('$agentName has joined the chat');
        }
        break;
        
      case 'session_closed':
        _addSystemMessage('Chat session has been closed');
        _sessionId = null;
        break;
    }
  }

  void _addSystemMessage(String message) {
    final systemMessage = ChatMessage(
      id: 'system_${DateTime.now().millisecondsSinceEpoch}',
      senderId: 'system',
      senderName: 'System',
      message: message,
      timestamp: DateTime.now(),
      isFromDriver: false,
      isSystem: true,
    );
    
    setState(() {
      _messages.add(systemMessage);
    });
    
    _scrollToBottom();
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    // Add message to UI immediately
    final message = ChatMessage(
      id: 'driver_${DateTime.now().millisecondsSinceEpoch}',
      senderId: widget.driverId,
      senderName: widget.driverName ?? 'You',
      message: messageText,
      timestamp: DateTime.now(),
      isFromDriver: true,
    );

    setState(() {
      _messages.add(message);
    });

    _messageController.clear();
    _scrollToBottom();

    // Send to backend
    final success = await _chatService.sendChatMessage(messageText, sessionId: _sessionId);
    
    if (!success) {
      _showErrorSnackBar('Failed to send message');
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

  void _vibrate() {
    HapticFeedback.lightImpact();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_agentName != null ? 'Chat with $_agentName' : 'Support Chat'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
              _isConnected ? Icons.wifi : Icons.wifi_off,
              color: _isConnected ? Colors.green : Colors.red,
            ),
            onPressed: () {
              _showErrorSnackBar(
                _isConnected ? 'Connected to support' : 'Disconnected from support',
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Connection Status
                if (!_isConnected)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    color: Colors.red[100],
                    child: const Row(
                      children: [
                        Icon(Icons.wifi_off, color: Colors.red),
                        SizedBox(width: 8),
                        Text(
                          'Reconnecting to support...',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                
                // Messages List
                Expanded(
                  child: _messages.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            return _buildMessageBubble(_messages[index]);
                          },
                        ),
                ),
                
                // Message Input
                _buildMessageInput(),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.support_agent,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'Welcome to WhizzDriver Support',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'How can we help you today?',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: message.isFromDriver
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!message.isFromDriver && !message.isSystem)
            GradientBorderContainer.circular(
              borderWidth: 2,
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.blue[100],
                child: const Icon(Icons.support_agent, size: 16),
              ),
            ),
          if (!message.isFromDriver && !message.isSystem)
            const SizedBox(width: 8),
          
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isSystem
                    ? Colors.grey[200]
                    : message.isFromDriver
                        ? Colors.blue[500]
                        : Colors.grey[300],
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!message.isFromDriver && !message.isSystem)
                    Text(
                      message.senderName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    ),
                  if (!message.isFromDriver && !message.isSystem)
                    const SizedBox(height: 4),
                  Text(
                    message.message,
                    style: TextStyle(
                      color: message.isSystem
                          ? Colors.grey[600]
                          : message.isFromDriver
                              ? Colors.white
                              : Colors.black87,
                      fontSize: message.isSystem ? 12 : 16,
                      fontStyle: message.isSystem ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: message.isSystem
                          ? Colors.grey[500]
                          : message.isFromDriver
                              ? Colors.white70
                              : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          if (message.isFromDriver)
            const SizedBox(width: 8),
          if (message.isFromDriver)
            GradientBorderContainer.circular(
              borderWidth: 2,
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.blue[700],
                child: Text(
                  widget.driverName?.substring(0, 1).toUpperCase() ?? 'D',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -2),
            blurRadius: 4,
            color: Colors.black.withOpacity(0.1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type your message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            onPressed: _isConnected ? _sendMessage : null,
            backgroundColor: _isConnected ? Colors.blue[500] : Colors.grey,
            child: const Icon(Icons.send, color: Colors.white),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.day}/${timestamp.month} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}

/// Chat Message Model
class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String message;
  final DateTime timestamp;
  final bool isFromDriver;
  final bool isSystem;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.timestamp,
    required this.isFromDriver,
    this.isSystem = false,
  });
}
