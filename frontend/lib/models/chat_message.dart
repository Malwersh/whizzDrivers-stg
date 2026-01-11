class ChatMessage {
  final String id;
  final String content; // Changed from 'text' to 'content'
  final String text; // Keep for backward compatibility
  final bool isFromDriver;
  final DateTime timestamp;
  final String senderName;
  final String senderId; // Added senderId
  final String? sessionId;
  final Map<String, dynamic>? metadata;

  ChatMessage({
    required this.id,
    String? content,
    String? text,
    required this.isFromDriver,
    required this.timestamp,
    required this.senderName,
    String? senderId,
    this.sessionId,
    this.metadata,
  }) : content = content ?? text ?? '',
       text = text ?? content ?? '',
       senderId = senderId ?? senderName;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? '',
      content: json['content'] ?? json['text'] ?? '',
      text: json['text'] ?? json['content'] ?? '',
      isFromDriver: json['isFromDriver'] ?? false,
      timestamp: DateTime.parse(json['timestamp']),
      senderName: json['senderName'] ?? '',
      senderId: json['senderId'] ?? json['senderName'] ?? '',
      sessionId: json['sessionId'],
      metadata: json['metadata']?.cast<String, dynamic>(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'text': text,
      'isFromDriver': isFromDriver,
      'timestamp': timestamp.toIso8601String(),
      'senderName': senderName,
      'senderId': senderId,
      'sessionId': sessionId,
      'metadata': metadata,
    };
  }

  ChatMessage copyWith({
    String? id,
    String? content,
    String? text,
    bool? isFromDriver,
    DateTime? timestamp,
    String? senderName,
    String? senderId,
    String? sessionId,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      text: text ?? this.text,
      isFromDriver: isFromDriver ?? this.isFromDriver,
      timestamp: timestamp ?? this.timestamp,
      senderName: senderName ?? this.senderName,
      senderId: senderId ?? this.senderId,
      sessionId: sessionId ?? this.sessionId,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'ChatMessage(id: $id, text: $text, isFromDriver: $isFromDriver, senderName: $senderName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ChatMessage &&
        other.id == id &&
        other.text == text &&
        other.isFromDriver == isFromDriver &&
        other.timestamp == timestamp &&
        other.senderName == senderName &&
        other.sessionId == sessionId;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      text,
      isFromDriver,
      timestamp,
      senderName,
      sessionId,
    );
  }
}
