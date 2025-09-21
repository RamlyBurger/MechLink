/// Helper functions for date and time formatting
class DateTimeHelper {
  /// Format date string to DD/MM/YYYY format
  static String formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  /// Format timestamp to readable format (DD/MM HH:MM)
  static String formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '--';
    
    try {
      DateTime dateTime;
      
      if (timestamp is Map) {
        // Handle various Firestore Timestamp formats
        if (timestamp.containsKey('_seconds')) {
          // Format: {_seconds: 1234567890, _nanoseconds: 123456789}
          dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp['_seconds'] * 1000);
        } else if (timestamp.containsKey('seconds')) {
          // Format: {seconds: 1234567890, nanoseconds: 123456789}
          dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp['seconds'] * 1000);
        } else {
          return '--';
        }
      } else if (timestamp is DateTime) {
        dateTime = timestamp;
      } else if (timestamp is int) {
        // Unix timestamp in seconds
        dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
      } else if (timestamp is String) {
        // Try parsing string timestamp
        dateTime = DateTime.parse(timestamp);
      } else {
        return '--';
      }
      
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      print('Error formatting timestamp: $e, timestamp: $timestamp');
      return '--';
    }
  }

  /// Format duration from seconds to HH:MM:SS
  static String formatDuration(double? seconds) {
    if (seconds == null) return '--:--:--';
    
    final duration = Duration(seconds: seconds.round());
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final secs = duration.inSeconds.remainder(60);
    
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Format duration from seconds to readable format (e.g., "2 hr 10 min", "45 min", "30 sec")
  static String formatReadableDuration(double? seconds) {
    if (seconds == null) return '--';
    
    final totalSeconds = seconds.round();
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final remainingSeconds = totalSeconds % 60;
    
    List<String> parts = [];
    
    if (hours > 0) {
      parts.add('$hours hr');
    }
    
    if (minutes > 0) {
      parts.add('$minutes min');
    }
    
    // Only show seconds if no hours/minutes, or if it's the only component
    if (parts.isEmpty || (hours == 0 && minutes == 0)) {
      if (remainingSeconds > 0 || parts.isEmpty) {
        parts.add('$remainingSeconds sec');
      }
    }
    
    return parts.join(' ');
  }

  /// Format date with full details (DD/MM/YYYY HH:MM)
  static String formatDateWithTime(dynamic timestamp) {
    if (timestamp == null) return '--';
    
    try {
      DateTime dateTime;
      
      if (timestamp is Map) {
        // Handle various Firestore Timestamp formats
        if (timestamp.containsKey('_seconds')) {
          dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp['_seconds'] * 1000);
        } else if (timestamp.containsKey('seconds')) {
          dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp['seconds'] * 1000);
        } else {
          return '--';
        }
      } else if (timestamp is DateTime) {
        dateTime = timestamp;
      } else if (timestamp is int) {
        dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
      } else if (timestamp is String) {
        dateTime = DateTime.parse(timestamp);
      } else {
        return '--';
      }
      
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      print('Error formatting date with time: $e, timestamp: $timestamp');
      return '--';
    }
  }

  /// Format date as relative time (e.g., "2h ago", "3d ago")
  static String formatRelativeDate(dynamic date) {
    try {
      DateTime dateTime;
      if (date is String) {
        dateTime = DateTime.parse(date);
      } else if (date is DateTime) {
        dateTime = date;
      } else if (date is Map) {
        // Handle Firestore Timestamp formats
        if (date.containsKey('_seconds')) {
          dateTime = DateTime.fromMillisecondsSinceEpoch(date['_seconds'] * 1000);
        } else if (date.containsKey('seconds')) {
          dateTime = DateTime.fromMillisecondsSinceEpoch(date['seconds'] * 1000);
        } else {
          return 'Unknown';
        }
      } else if (date is int) {
        dateTime = DateTime.fromMillisecondsSinceEpoch(date * 1000);
      } else {
        return 'Unknown';
      }

      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  /// Format date with hybrid approach: absolute date for old entries (>30 days), relative for recent
  static String formatHybridDate(dynamic date) {
    try {
      DateTime dateTime;
      if (date is Map && date.containsKey('seconds')) {
        // Firestore Timestamp format
        dateTime = DateTime.fromMillisecondsSinceEpoch(date['seconds'] * 1000);
      } else if (date is Map && date.containsKey('_seconds')) {
        // Alternative Firestore Timestamp format
        dateTime = DateTime.fromMillisecondsSinceEpoch(date['_seconds'] * 1000);
      } else if (date is String) {
        dateTime = DateTime.parse(date);
      } else if (date is DateTime) {
        dateTime = date;
      } else if (date is int) {
        dateTime = DateTime.fromMillisecondsSinceEpoch(date * 1000);
      } else {
        return 'Unknown';
      }

      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 30) {
        // Show absolute date for entries older than 30 days
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      } else if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  /// Format date for join date (MM/YYYY format)
  static String formatJoinDate(dynamic date) {
    try {
      DateTime dateTime;
      if (date is Map && date.containsKey('seconds')) {
        // Firestore Timestamp format
        dateTime = DateTime.fromMillisecondsSinceEpoch(date['seconds'] * 1000);
      } else if (date is Map && date.containsKey('_seconds')) {
        // Alternative Firestore Timestamp format
        dateTime = DateTime.fromMillisecondsSinceEpoch(date['_seconds'] * 1000);
      } else if (date is String) {
        dateTime = DateTime.parse(date);
      } else if (date is DateTime) {
        dateTime = date;
      } else if (date is int) {
        dateTime = DateTime.fromMillisecondsSinceEpoch(date * 1000);
      } else {
        return 'Unknown';
      }
      
      return '${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return 'Unknown';
    }
  }
}
