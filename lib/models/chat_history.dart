class ChatHistory {
  final String id;
  final String mechanicId;
  final String? title;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChatHistory({
    required this.id,
    required this.mechanicId,
    this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatHistory.fromMap(Map<String, dynamic> map) {
    return ChatHistory(
      id: map['id'] ?? '',
      mechanicId: map['mechanicId'] ?? '',
      title: map['title'],
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'mechanicId': mechanicId,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
