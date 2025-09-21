import 'package:flutter/foundation.dart';
import 'auth_service.dart';

enum PasswordStrength { weak, medium, strong }

class ChangePasswordService {
  // Private constructor
  ChangePasswordService._();

  // Singleton instance
  static final ChangePasswordService _instance = ChangePasswordService._();

  // Factory constructor to return the singleton instance
  factory ChangePasswordService() => _instance;

  final AuthService _authService = AuthService();

  // Verify current password
  Future<bool> verifyCurrentPassword(String currentPassword) async {
    try {
      return await _authService.verifyCurrentPassword(currentPassword);
    } catch (e) {
      debugPrint('❌ Error verifying current password: $e');
      return false;
    }
  }

  // Calculate password strength
  PasswordStrength calculatePasswordStrength(String password) {
    if (password.isEmpty) return PasswordStrength.weak;

    int score = 0;

    // Length checks
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;

    // Character variety checks
    if (password.contains(RegExp(r'[a-z]'))) score++;
    if (password.contains(RegExp(r'[A-Z]'))) score++;
    if (password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) score++;

    if (score <= 2) return PasswordStrength.weak;
    if (score <= 4) return PasswordStrength.medium;
    return PasswordStrength.strong;
  }

  // Get password strength color
  String getPasswordStrengthColor(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.weak:
        return '#EF4444'; // Red
      case PasswordStrength.medium:
        return '#F59E0B'; // Orange
      case PasswordStrength.strong:
        return '#10B981'; // Green
    }
  }

  // Get password strength text
  String getPasswordStrengthText(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.weak:
        return 'Weak';
      case PasswordStrength.medium:
        return 'Medium';
      case PasswordStrength.strong:
        return 'Strong';
    }
  }

  // Get password strength value (0.0 to 1.0)
  double getPasswordStrengthValue(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.weak:
        return 0.33;
      case PasswordStrength.medium:
        return 0.66;
      case PasswordStrength.strong:
        return 1.0;
    }
  }

  // Validate password requirements
  Map<String, bool> validatePasswordRequirements(String password) {
    return {
      'minLength': password.length >= 8,
      'hasLowercase': password.contains(RegExp(r'[a-z]')),
      'hasUppercase': password.contains(RegExp(r'[A-Z]')),
      'hasNumbers': password.contains(RegExp(r'[0-9]')),
      'hasSpecialChars': password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]')),
    };
  }

  // Get password requirements text
  List<String> getPasswordRequirements() {
    return [
      'At least 8 characters long',
      'Contains lowercase letters (a-z)',
      'Contains uppercase letters (A-Z)',
      'Contains numbers (0-9)',
      'Contains special characters (!@#\$%^&*)',
    ];
  }

  // Validate password change request
  Future<bool> validatePasswordChange({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      // Verify current password first
      final isCurrentPasswordValid = await verifyCurrentPassword(currentPassword);
      if (!isCurrentPasswordValid) {
        debugPrint('❌ Current password is invalid');
        return false;
      }

      // Check new password strength
      final strength = calculatePasswordStrength(newPassword);
      if (strength == PasswordStrength.weak) {
        debugPrint('❌ New password is too weak');
        return false;
      }

      debugPrint('✅ Password change validation successful');
      return true;
    } catch (e) {
      debugPrint('❌ Error validating password change: $e');
      return false;
    }
  }

  // Update password (called from OTP screen after verification)
  Future<bool> updatePassword(String newPassword) async {
    try {
      final success = await _authService.updatePassword(newPassword);
      
      if (success) {
        debugPrint('✅ Password updated successfully');
        return true;
      } else {
        debugPrint('❌ Failed to update password');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error updating password: $e');
      return false;
    }
  }
}
