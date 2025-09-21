class NotificationItem {
  final String id;
  final String mechanicId;
  final String title;
  final String message;
  final DateTime created;

  const NotificationItem({
    required this.id,
    required this.mechanicId,
    required this.title,
    required this.message,
    required this.created,
  });

  factory NotificationItem.fromMap(Map<String, dynamic> map) {
    return NotificationItem(
      id: map['id'] ?? '',
      mechanicId: map['mechanicId'] ?? '',
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      created: DateTime.parse(map['created']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'mechanicId': mechanicId,
      'title': title,
      'message': message,
      'created': created.toIso8601String(),
    };
  }
}
