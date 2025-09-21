import 'package:flutter/material.dart';
import 'package:mechlink/models/notification.dart';
import 'package:mechlink/services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with TickerProviderStateMixin {
  final NotificationService _notificationService = NotificationService();
  bool _isLoading = false;
  List<NotificationItem> _notifications = [];

  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _loadNotifications();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);

    try {
      await _notificationService.loadNotifications();
      setState(() {
        _notifications = List.from(_notificationService.notifications);
      });
    } catch (e) {
      print('Error loading notifications: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeNotification(String notificationId) async {
    final success = await _notificationService.removeNotification(
      notificationId,
    );
    if (success) {
      // Reload notifications from service to get updated list
      setState(() {
        _notifications = List.from(_notificationService.notifications);
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Notification removed')));
      }
    }
  }

  Future<void> _clearAllNotifications() async {
    if (_notifications.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text(
          'Are you sure you want to clear all notifications? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _notificationService.clearAllNotifications();
      if (success) {
        setState(() {
          _notifications = List.from(_notificationService.notifications);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All notifications cleared')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_notifications.isNotEmpty)
            IconButton(
              onPressed: _clearAllNotifications,
              icon: const Icon(Icons.clear_all),
              tooltip: 'Clear All',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF3B82F6),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading notifications...',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 16),
                  ),
                ],
              ),
            )
          : AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: _buildNotificationsList(),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildNotificationsList() {
    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none,
                size: 60,
                color: Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Notifications',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You\'re all caught up! No new notifications.',
              style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      color: const Color(0xFF3B82F6),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          return _buildNotificationCard(notification, index);
        },
      ),
    );
  }

  Widget _buildNotificationCard(NotificationItem notification, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Dismissible(
        key: Key(notification.id),
        direction: DismissDirection.endToStart,
        background: Container(
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(Icons.delete, color: Colors.white, size: 24),
        ),
        onDismissed: (direction) {
          _removeNotification(notification.id);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getNotificationColor(
                        notification.title,
                      ).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getNotificationIcon(notification.title),
                      color: _getNotificationColor(notification.title),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification.message,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _notificationService.formatNotificationTime(
                            notification.created,
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _removeNotification(notification.id),
                    icon: const Icon(
                      Icons.close,
                      color: Color(0xFF94A3B8),
                      size: 18,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getNotificationIcon(String title) {
    final titleLower = title.toLowerCase();
    if (titleLower.contains('salary') || titleLower.contains('payment')) {
      return Icons.attach_money;
    } else if (titleLower.contains('meeting') || titleLower.contains('team')) {
      return Icons.group;
    } else if (titleLower.contains('system') || titleLower.contains('update')) {
      return Icons.system_update;
    } else if (titleLower.contains('assigned') || titleLower.contains('job')) {
      return Icons.work;
    } else if (titleLower.contains('repair') ||
        titleLower.contains('maintenance')) {
      return Icons.build;
    } else {
      return Icons.notifications;
    }
  }

  Color _getNotificationColor(String title) {
    final titleLower = title.toLowerCase();
    if (titleLower.contains('salary') || titleLower.contains('payment')) {
      return Colors.green;
    } else if (titleLower.contains('meeting') || titleLower.contains('team')) {
      return Colors.blue;
    } else if (titleLower.contains('system') || titleLower.contains('update')) {
      return Colors.orange;
    } else if (titleLower.contains('assigned') || titleLower.contains('job')) {
      return Colors.purple;
    } else if (titleLower.contains('repair') ||
        titleLower.contains('maintenance')) {
      return const Color(0xFF3B82F6);
    } else {
      return const Color(0xFF64748B);
    }
  }
}
