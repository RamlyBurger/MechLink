import 'package:mechlink/services/auth_service.dart';
import 'package:mechlink/models/mechanic.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:typed_data';

class ProfileService {
  // Private constructor
  ProfileService._();

  // Singleton instance
  static final ProfileService _instance = ProfileService._();

  // Factory constructor to return the singleton instance
  factory ProfileService() => _instance;

  final AuthService _authService = AuthService();

  /// Get current mechanic profile
  Mechanic? get currentMechanic {
    final mechanicData = _authService.currentMechanic;
    if (mechanicData != null) {
      return Mechanic.fromMap(mechanicData);
    }
    return null;
  }

  /// Update personal information
  Future<bool> updatePersonalInfo({
    String? name,
    String? email,
    String? phone,
    String? bio,
    String? department,
    String? specialization,
  }) async {
    try {
      final mechanicId = _authService.currentMechanicId;
      if (mechanicId == null) return false;

      Map<String, dynamic> updates = {};
      if (name != null) updates['name'] = name;
      if (email != null) updates['email'] = email;
      if (phone != null) updates['phone'] = phone;
      if (bio != null) updates['bio'] = bio;
      if (department != null) updates['department'] = department;
      if (specialization != null) updates['specialization'] = specialization;

      if (updates.isEmpty) return true;

      return await _authService.updateMechanicProfile(mechanicId, updates);
    } catch (e) {
      print('Error updating personal info: $e');
      return false;
    }
  }

  /// Update mechanic information
  Future<bool> updateMechanicInfo({
    String? department,
    String? specialization,
    String? employeeId,
    MechanicRole? role,
  }) async {
    try {
      final mechanicId = _authService.currentMechanicId;
      if (mechanicId == null) return false;

      Map<String, dynamic> updates = {};
      if (department != null) updates['department'] = department;
      if (specialization != null) updates['specialization'] = specialization;
      if (employeeId != null) updates['employeeId'] = employeeId;
      if (role != null) updates['role'] = role.toString().split('.').last;

      if (updates.isEmpty) return true;

      return await _authService.updateMechanicProfile(mechanicId, updates);
    } catch (e) {
      print('Error updating mechanic info: $e');
      return false;
    }
  }

  /// Change password
  Future<bool> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      final mechanicId = _authService.currentMechanicId;
      if (mechanicId == null) return false;

      // In a real app, you would verify the current password first
      // For demo purposes, we'll just update the password hash
      Map<String, dynamic> updates = {
        'passwordHash': newPassword, // In production, hash this properly
      };

      return await _authService.updateMechanicProfile(mechanicId, updates);
    } catch (e) {
      print('Error changing password: $e');
      return false;
    }
  }

  /// Update status
  Future<bool> updateStatus(MechanicStatus status) async {
    try {
      final mechanicId = _authService.currentMechanicId;
      if (mechanicId == null) return false;

      Map<String, dynamic> updates = {
        'status': status.toString().split('.').last,
      };

      return await _authService.updateMechanicProfile(mechanicId, updates);
    } catch (e) {
      print('Error updating status: $e');
      return false;
    }
  }

  /// Update avatar
  Future<bool> updateAvatar(String? avatarUrl) async {
    try {
      final mechanicId = _authService.currentMechanicId;
      if (mechanicId == null) return false;

      Map<String, dynamic> updates = {'avatar': avatarUrl};

      return await _authService.updateMechanicProfile(mechanicId, updates);
    } catch (e) {
      print('Error updating avatar: $e');
      return false;
    }
  }

  /// Pick image from camera
  Future<String?> pickImageFromCamera() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        final Uint8List imageBytes = await image.readAsBytes();
        final String base64Image = base64Encode(imageBytes);
        return 'data:image/jpeg;base64,$base64Image';
      }
      return null;
    } catch (e) {
      print('Error picking image from camera: $e');
      return null;
    }
  }

  /// Pick image from gallery
  Future<String?> pickImageFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        final Uint8List imageBytes = await image.readAsBytes();
        final String base64Image = base64Encode(imageBytes);
        return 'data:image/jpeg;base64,$base64Image';
      }
      return null;
    } catch (e) {
      print('Error picking image from gallery: $e');
      return null;
    }
  }

  /// Update profile picture with image picker options
  Future<bool> updateProfilePicture() async {
    try {
      // This method will be called from the UI to show picker options
      return true;
    } catch (e) {
      print('Error updating profile picture: $e');
      return false;
    }
  }

  /// Logout user
  Future<void> logout() async {
    await _authService.logout();
  }

  /// Reload profile data
  Future<bool> reloadProfile() async {
    try {
      final mechanicId = _authService.currentMechanicId;
      if (mechanicId == null) return false;

      var mechanicData = await _authService.getMechanicById(mechanicId);
      if (mechanicData != null) {
        // Convert Firestore Timestamps to proper DateTime strings
        mechanicData = _convertTimestamps(mechanicData);
        _authService.setCurrentMechanic(mechanicData);
        return true;
      }
      return false;
    } catch (e) {
      print('Error reloading profile: $e');
      return false;
    }
  }

  /// Convert Firestore Timestamp objects to ISO8601 strings
  Map<String, dynamic> _convertTimestamps(Map<String, dynamic> data) {
    final convertedData = Map<String, dynamic>.from(data);

    // List of fields that might contain Timestamps
    final timestampFields = ['createdAt', 'updatedAt', 'lastLoginAt'];

    for (final field in timestampFields) {
      if (convertedData[field] != null) {
        final value = convertedData[field];
        if (value.runtimeType.toString().contains('Timestamp')) {
          // Convert Firestore Timestamp to DateTime then to ISO8601 string
          final timestamp = value as dynamic;
          convertedData[field] = DateTime.fromMillisecondsSinceEpoch(
            timestamp.millisecondsSinceEpoch,
          ).toIso8601String();
        }
      }
    }

    return convertedData;
  }

  /// Get profile statistics
  Map<String, dynamic> getProfileStats() {
    final mechanic = currentMechanic;
    if (mechanic == null) return {};

    return {
      'memberSince': mechanic.createdAt,
      'lastLogin': mechanic.lastLoginAt,
    };
  }
}
