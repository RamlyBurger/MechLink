import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';

class AuthService {
  // Private constructor
  AuthService._();

  // Singleton instance
  static final AuthService _instance = AuthService._();

  // Factory constructor to return the singleton instance
  factory AuthService() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
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

      // Generate and store device ID for this login session
      await _generateDeviceId();

      // Save login state to SharedPreferences for persistence
      debugPrint('🔐 About to save login state...');
      await _saveLoginState(mechanicData);
      debugPrint('🔐 Login state save completed');

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

  // Generate and store device ID for current user
  Future<void> _generateDeviceId() async {
    try {
      if (_currentMechanicId == null) return;

      final prefs = await SharedPreferences.getInstance();
      final deviceIdKey = 'device_id_$_currentMechanicId';

      // Generate new unique device ID for this login session
      final random = Random();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final randomSuffix = random.nextInt(999999).toString().padLeft(6, '0');

      String deviceId =
          'device_${_currentMechanicId}_${timestamp}_$randomSuffix';

      // Store device ID
      await prefs.setString(deviceIdKey, deviceId);

      debugPrint(
        'Generated device ID for mechanic $_currentMechanicId: $deviceId',
      );
    } catch (e) {
      debugPrint('Error generating device ID: $e');
    }
  }

  // Get current device ID
  Future<String?> getCurrentDeviceId() async {
    try {
      if (_currentMechanicId == null) return null;

      final prefs = await SharedPreferences.getInstance();
      final deviceIdKey = 'device_id_$_currentMechanicId';

      return prefs.getString(deviceIdKey);
    } catch (e) {
      debugPrint('Error getting device ID: $e');
      return null;
    }
  }

  // Verify current password for password change
  Future<bool> verifyCurrentPassword(String currentPassword) async {
    if (_currentMechanic == null) {
      debugPrint('❌ No current mechanic data available');
      return false;
    }

    final storedHash = _currentMechanic!['passwordHash'] ?? '';
    debugPrint('🔐 Verifying password for user: ${_currentMechanic!['email']}');
    debugPrint('🔐 Stored hash exists: ${storedHash.isNotEmpty}');
    debugPrint('🔐 Stored hash length: ${storedHash.length}');
    debugPrint('🔐 Input password length: ${currentPassword.length}');

    if (storedHash.isEmpty) {
      debugPrint('❌ No password hash stored for user');
      return false;
    }

    final result = _verifyPassword(currentPassword, storedHash);
    debugPrint('🔐 Bcrypt verification result: $result');
    return result;
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

      debugPrint('💾 Login state saved for mechanic: ${mechanicData['id']}');
      debugPrint('💾 Saved data keys: ${prefs.getKeys()}');
      debugPrint('💾 is_logged_in: ${prefs.getBool('is_logged_in')}');
    } catch (e) {
      debugPrint('❌ Error saving login state: $e');
    }
  }

  // Restore login state from SharedPreferences
  Future<bool> restoreLoginState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      debugPrint('🔄 Attempting to restore login state...');
      debugPrint('🔄 Available keys: ${prefs.getKeys()}');

      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
      debugPrint('🔄 is_logged_in flag: $isLoggedIn');

      if (!isLoggedIn) {
        debugPrint('🔄 User not marked as logged in');
        return false;
      }

      final mechanicId = prefs.getString('logged_in_mechanic_id');
      final mechanicDataString = prefs.getString('logged_in_mechanic_data');

      debugPrint('🔄 mechanicId: $mechanicId');
      debugPrint('🔄 mechanicDataString exists: ${mechanicDataString != null}');

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
              debugPrint('⚠️ Could not parse timestamp for field $field: $e');
            }
          }
        }

        _currentMechanic = decodedData;
        debugPrint('✅ Login state restored for mechanic: $mechanicId');
        return true;
      } else {
        debugPrint('❌ Missing mechanic data in SharedPreferences');
      }
    } catch (e) {
      debugPrint('❌ Error restoring login state: $e');
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

      // Clear device ID
      if (_currentMechanicId != null) {
        await prefs.remove('device_id_$_currentMechanicId');
      }

      // Clear memory state
      _currentMechanicId = null;
      _currentMechanic = null;

      debugPrint('User logged out successfully');
    } catch (e) {
      debugPrint('Error during logout: $e');
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
