
enum ChatMessageType {
  toMerchant,
  fromMerchant,
  toCustomer,
  fromCustomer,
  system,
}

/// Chat message model for driver communication
class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String recipientId;
  final String recipientName;
  final String message;
  final DateTime timestamp;
  final ChatMessageType type;
  final String? orderId;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.recipientId,
    required this.recipientName,
    required this.message,
    required this.timestamp,
    required this.type,
    this.orderId,
  });
}
