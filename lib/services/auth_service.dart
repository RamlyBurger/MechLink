import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'fcm_service.dart';

class AuthService {
  // Private constructor
  AuthService._();

  // Singleton instance
  static final AuthService _instance = AuthService._();

  // Factory constructor to return the singleton instance
  factory AuthService() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FCMService _fcmService = FCMService();
  String? _currentMechanicId;
  Map<String, dynamic>? _currentMechanic;

  String? get currentMechanicId => _currentMechanicId;
  Map<String, dynamic>? get currentMechanic => _currentMechanic;
  bool get isLoggedIn => _currentMechanicId != null;

  // Login function using email and password
  Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      // Get all mechanics and filter by email
      QuerySnapshot querySnapshot = await _firestore
          .collection('mechanics')
          .get();

      List<QueryDocumentSnapshot> mechanics = querySnapshot.docs.where((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return data['email'] == email;
      }).toList();

      if (mechanics.isEmpty) {
        return null; // No mechanic found with this email
      }

      DocumentSnapshot mechDoc = mechanics.first;
      Map<String, dynamic> mechanicData =
          mechDoc.data() as Map<String, dynamic>;

      // In a real app, you would verify the password hash
      // For demo purposes, we'll use a simple check
      String storedPasswordHash = mechanicData['passwordHash'] ?? '';

      // Simplified password verification (in production, use proper hashing)
      bool passwordValid = _verifyPassword(password, storedPasswordHash);

      if (!passwordValid) {
        return null; // Invalid password
      }

      // Update last login time
      await _firestore.collection('mechanics').doc(mechDoc.id).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });

      // Store current mechanic data with documentId
      mechanicData['documentId'] = mechDoc.id;
      _currentMechanicId = mechanicData['id'];
      _currentMechanic = mechanicData;

      // Initialize FCM and generate token for this login session
      await _initializeFCM();

      // Save login state to SharedPreferences for persistence
      await _saveLoginState(mechanicData);

      return mechanicData;
    } catch (e) {
      print('Login error: $e');
      return null;
    }
  }

  // Password verification using bcrypt
  bool _verifyPassword(String password, String hash) {
    try {
      return BCrypt.checkpw(password, hash);
    } catch (e) {
      return false;
    }
  }

  // Hash password using bcrypt
  static String hashPassword(String password) {
    final salt = BCrypt.gensalt();
    return BCrypt.hashpw(password, salt);
  }

  // Initialize FCM service and generate token for current user
  Future<void> _initializeFCM() async {
    try {
      if (_currentMechanicId == null) return;

      // Initialize FCM service
      await _fcmService.initialize();

      // Get FCM token for this mechanic
      String? fcmToken = await _fcmService.getTokenForMechanic(
        _currentMechanicId!,
      );

      if (fcmToken != null) {
        print(
          'FCM token generated for mechanic $_currentMechanicId: $fcmToken',
        );
      } else {
        print('Failed to generate FCM token for mechanic $_currentMechanicId');
      }
    } catch (e) {
      print('FCM initialization error: $e');
    }
  }

  // Get current FCM token (replaces device ID)
  Future<String?> getCurrentFCMToken() async {
    try {
      if (_currentMechanicId == null) return null;

      return await _fcmService.getTokenForMechanic(_currentMechanicId!);
    } catch (e) {
      print('Error getting FCM token: $e');
      return null;
    }
  }

  // Get current device ID (deprecated - use getCurrentFCMToken instead)
  @deprecated
  Future<String?> getCurrentDeviceId() async {
    // For backward compatibility, return FCM token
    return await getCurrentFCMToken();
  }

  // Verify current password for password change
  Future<bool> verifyCurrentPassword(String currentPassword) async {
    if (_currentMechanic == null) {
      return false;
    }

    final storedHash = _currentMechanic!['passwordHash'] ?? '';

    if (storedHash.isEmpty) {
      return false;
    }

    return _verifyPassword(currentPassword, storedHash);
  }

  // Update password with new hash
  Future<bool> updatePassword(String newPassword) async {
    if (_currentMechanicId == null || _currentMechanic == null) return false;

    try {
      final newHash = hashPassword(newPassword);
      final docId = _currentMechanic!['documentId'];

      await _firestore.collection('mechanics').doc(docId).update({
        'passwordHash': newHash,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update local cache
      _currentMechanic!['passwordHash'] = newHash;

      return true;
    } catch (e) {
      print('Password update error: $e');
      return false;
    }
  }

  // Save login state to SharedPreferences
  Future<void> _saveLoginState(Map<String, dynamic> mechanicData) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Create a copy of mechanicData and convert Timestamps to strings
      Map<String, dynamic> serializableData = Map<String, dynamic>.from(
        mechanicData,
      );

      // Convert any Timestamp objects to ISO8601 strings
      serializableData.forEach((key, value) {
        if (value is Timestamp) {
          serializableData[key] = value.toDate().toIso8601String();
        }
      });

      await prefs.setString('logged_in_mechanic_id', mechanicData['id']);
      await prefs.setString(
        'logged_in_mechanic_data',
        json.encode(serializableData),
      );
      await prefs.setBool('is_logged_in', true);
    } catch (e) {
      // Silent fail - login state saving is not critical for immediate functionality
    }
  }

  // Restore login state from SharedPreferences
  Future<bool> restoreLoginState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;

      if (!isLoggedIn) {
        return false;
      }

      final mechanicId = prefs.getString('logged_in_mechanic_id');
      final mechanicDataString = prefs.getString('logged_in_mechanic_data');

      if (mechanicId != null && mechanicDataString != null) {
        _currentMechanicId = mechanicId;

        // Decode the JSON data
        Map<String, dynamic> decodedData = json.decode(mechanicDataString);

        // Convert ISO8601 strings back to DateTime objects for common timestamp fields
        final timestampFields = ['createdAt', 'updatedAt', 'lastLoginAt'];
        for (String field in timestampFields) {
          if (decodedData[field] is String) {
            try {
              decodedData[field] = DateTime.parse(decodedData[field]);
            } catch (e) {
              // Silent fail for timestamp parsing
            }
          }
        }

        _currentMechanic = decodedData;
        return true;
      }
    } catch (e) {
      // Silent fail - will show login screen
    }
    return false;
  }

  // Logout function
  Future<void> logout() async {
    try {
      // Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('logged_in_mechanic_id');
      await prefs.remove('logged_in_mechanic_data');
      await prefs.setBool('is_logged_in', false);

      // Clear FCM token
      await _fcmService.clearToken();

      // Clear memory state
      _currentMechanicId = null;
      _currentMechanic = null;
    } catch (e) {
      // Silent fail
    }
  }

  // Set current mechanic (for reloading data)
  void setCurrentMechanic(Map<String, dynamic> mechanicData) {
    _currentMechanic = mechanicData;
    _currentMechanicId = mechanicData['id'];
  }

  // Get mechanic by ID
  Future<Map<String, dynamic>?> getMechanicById(String mechanicId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('mechanics')
          .doc(mechanicId)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['documentId'] = doc.id;
        return data;
      }
      return null;
    } catch (e) {
      print('Error getting mechanic: $e');
      return null;
    }
  }

  // Update mechanic profile
  Future<bool> updateMechanicProfile(
    String mechanicId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _firestore.collection('mechanics').doc(mechanicId).update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update local cache if it's the current user
      if (_currentMechanicId == mechanicId && _currentMechanic != null) {
        _currentMechanic!.addAll(updates);
      }

      return true;
    } catch (e) {
      print('Error updating mechanic profile: $e');
      return false;
    }
  }
}
