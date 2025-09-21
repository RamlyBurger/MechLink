import 'package:mechlink/models/notification.dart';
import 'package:mechlink/services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  // Private constructor
  NotificationService._();

  // Singleton instance
  static final NotificationService _instance = NotificationService._();

  // Factory constructor to return the singleton instance
  factory NotificationService() => _instance;

  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<NotificationItem> _notifications = [];

  /// Get all notifications for the current mechanic
  List<NotificationItem> get notifications => List.unmodifiable(_notifications);

  /// Load notifications from Firestore
  Future<void> loadNotifications() async {
    try {
      final mechanicId = _authService.currentMechanicId;
      if (mechanicId == null) return;

      // Query Firestore for notifications for the current mechanic
      QuerySnapshot querySnapshot = await _firestore
          .collection('notifications')
          .where('mechanicId', isEqualTo: mechanicId)
          .orderBy('created', descending: true)
          .get();

      _notifications = querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // Use document ID as notification ID

        // Convert Firestore Timestamp to DateTime if needed
        if (data['created'] is Timestamp) {
          data['created'] = (data['created'] as Timestamp)
              .toDate()
              .toIso8601String();
        }

        return NotificationItem.fromMap(data);
      }).toList();
    } catch (e) {
      print('Error loading notifications: $e');
      _notifications = [];
    }
  }

  /// Remove a specific notification
  Future<bool> removeNotification(String notificationId) async {
    try {
      // Remove from Firestore first
      await _firestore.collection('notifications').doc(notificationId).delete();

      // Remove from local cache
      _notifications = _notifications
          .where((notification) => notification.id != notificationId)
          .toList();
      return true;
    } catch (e) {
      print('Error removing notification: $e');
      return false;
    }
  }

  /// Clear all notifications for the current mechanic
  Future<bool> clearAllNotifications() async {
    try {
      final mechanicId = _authService.currentMechanicId;
      if (mechanicId == null) return false;

      // Get all notifications for this mechanic and delete them
      QuerySnapshot querySnapshot = await _firestore
          .collection('notifications')
          .where('mechanicId', isEqualTo: mechanicId)
          .get();

      // Delete all notifications in a batch
      WriteBatch batch = _firestore.batch();
      for (QueryDocumentSnapshot doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Clear local cache
      _notifications.clear();
      return true;
    } catch (e) {
      print('Error clearing notifications: $e');
      return false;
    }
  }

  /// Create a new notification
  Future<bool> createNotification({
    required String mechanicId,
    required String title,
    required String message,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'mechanicId': mechanicId,
        'title': title,
        'message': message,
        'created': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error creating notification: $e');
      return false;
    }
  }

  /// Listen to real-time notifications updates
  Stream<List<NotificationItem>> getNotificationsStream() {
    final mechanicId = _authService.currentMechanicId;
    if (mechanicId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('notifications')
        .where('mechanicId', isEqualTo: mechanicId)
        .orderBy('created', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            Map<String, dynamic> data = doc.data();
            data['id'] = doc.id;

            // Convert Firestore Timestamp to DateTime if needed
            if (data['created'] is Timestamp) {
              data['created'] = (data['created'] as Timestamp)
                  .toDate()
                  .toIso8601String();
            }

            return NotificationItem.fromMap(data);
          }).toList();
        });
  }

  /// Get notification count
  int get notificationCount => _notifications.length;

  /// Check if there are unread notifications (for badge display)
  bool get hasNotifications => _notifications.isNotEmpty;

  /// Format notification time
  String formatNotificationTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }
}
