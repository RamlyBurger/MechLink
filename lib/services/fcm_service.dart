import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class FCMService {
  // Private constructor
  FCMService._();

  // Singleton instance
  static final FCMService _instance = FCMService._();

  // Factory constructor to return the singleton instance
  factory FCMService() => _instance;

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  String? _currentToken;

  String? get currentToken => _currentToken;

  /// Initialize FCM service and request permissions
  Future<void> initialize() async {
    try {
      // Request permission for notifications
      NotificationSettings settings = await _firebaseMessaging
          .requestPermission(
            alert: true,
            announcement: false,
            badge: true,
            carPlay: false,
            criticalAlert: false,
            provisional: false,
            sound: true,
          );

      if (kDebugMode) {
        print('FCM Permission granted: ${settings.authorizationStatus}');
      }

      // Get the FCM token
      await _generateAndStoreToken();

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _currentToken = newToken;
        _storeTokenLocally(newToken);
        if (kDebugMode) {
          print('FCM Token refreshed: $newToken');
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('FCM initialization error: $e');
      }
    }
  }

  /// Generate and store FCM token
  Future<String?> _generateAndStoreToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();

      if (token != null) {
        _currentToken = token;
        await _storeTokenLocally(token);

        if (kDebugMode) {
          print('FCM Token generated: $token');
        }

        return token;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error generating FCM token: $e');
      }
    }
    return null;
  }

  /// Store FCM token locally for the current user
  Future<void> _storeTokenLocally(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);
    } catch (e) {
      if (kDebugMode) {
        print('Error storing FCM token locally: $e');
      }
    }
  }

  /// Get stored FCM token for current user
  Future<String?> getStoredToken() async {
    try {
      // First try to get from memory
      if (_currentToken != null) {
        return _currentToken;
      }

      // Then try to get from local storage
      final prefs = await SharedPreferences.getInstance();
      String? storedToken = prefs.getString('fcm_token');

      if (storedToken != null) {
        _currentToken = storedToken;
        return storedToken;
      }

      // If no stored token, generate a new one
      return await _generateAndStoreToken();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting stored FCM token: $e');
      }
      return null;
    }
  }

  /// Get FCM token for a specific mechanic (for notifications)
  Future<String?> getTokenForMechanic(String mechanicId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('fcm_token_$mechanicId');

      // If no specific token for this mechanic, use the general token
      if (token == null) {
        token = await getStoredToken();

        // Store it for this specific mechanic
        if (token != null) {
          await prefs.setString('fcm_token_$mechanicId', token);
        }
      }

      return token;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting FCM token for mechanic $mechanicId: $e');
      }
      return null;
    }
  }

  /// Clear FCM token (for logout)
  Future<void> clearToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Clear general token
      await prefs.remove('fcm_token');

      // Clear all mechanic-specific tokens
      final keys = prefs.getKeys();
      for (String key in keys) {
        if (key.startsWith('fcm_token_')) {
          await prefs.remove(key);
        }
      }

      _currentToken = null;

      // Delete token from Firebase
      await _firebaseMessaging.deleteToken();

      if (kDebugMode) {
        print('FCM token cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing FCM token: $e');
      }
    }
  }

  /// Check if FCM token is valid (basic validation)
  bool isValidToken(String? token) {
    if (token == null || token.isEmpty) {
      return false;
    }

    // FCM tokens are typically long strings (140+ characters)
    // and don't start with "device_" (which is our custom device ID format)
    return token.length > 100 && !token.startsWith('device_');
  }

  /// Setup foreground message handling
  void setupForegroundMessageHandling() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('Received foreground message: ${message.notification?.title}');
      }
      // Handle foreground messages here
      // You can show local notifications or update UI
    });
  }

  /// Setup background message handling
  static Future<void> setupBackgroundMessageHandling() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print('Handling background message: ${message.notification?.title}');
  }
  // Handle background messages here
}
