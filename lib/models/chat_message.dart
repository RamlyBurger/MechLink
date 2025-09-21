enum MessageSender { bot, mechanic }

enum MessageType { text, image, file }

class ChatMessage {
  final String id;
  final MessageSender sender;
  final String chatHistoryId;
  final DateTime createdAt;
  final String content;
  final MessageType type;
  final String? base64Image;

  const ChatMessage({
    required this.id,
    required this.sender,
    required this.chatHistoryId,
    required this.createdAt,
    required this.content,
    required this.type,
    this.base64Image,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] ?? '',
      sender: MessageSender.values.firstWhere(
        (e) => e.toString().split('.').last == (map['sender'] ?? 'bot'),
        orElse: () => MessageSender.bot,
      ),
      chatHistoryId: map['chatHistoryId'] ?? '',
      createdAt: _parseDateTime(map['createdAt']),
      content: map['content'] ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.toString().split('.').last == (map['type'] ?? 'text'),
        orElse: () => MessageType.text,
      ),
      base64Image: map['base64Image'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender': sender.toString().split('.').last,
      'chatHistoryId': chatHistoryId,
      'createdAt': createdAt.toIso8601String(),
      'content': content,
      'type': type.toString().split('.').last,
      'base64Image': base64Image,
    };
  }

  ChatMessage copyWith({
    String? id,
    MessageSender? sender,
    String? chatHistoryId,
    DateTime? createdAt,
    String? content,
    MessageType? type,
    String? base64Image,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      chatHistoryId: chatHistoryId ?? this.chatHistoryId,
      createdAt: createdAt ?? this.createdAt,
      content: content ?? this.content,
      type: type ?? this.type,
      base64Image: base64Image ?? this.base64Image,
    );
  }

  static DateTime _parseDateTime(dynamic dateTime) {
    if (dateTime == null) {
      return DateTime.now();
    }
    if (dateTime is DateTime) {
      return dateTime;
    }
    if (dateTime is String) {
      return DateTime.parse(dateTime);
    }
    // Handle Firestore Timestamp
    if (dateTime.runtimeType.toString() == 'Timestamp') {
      return (dateTime as dynamic).toDate();
    }
    return DateTime.now();
  }
}
