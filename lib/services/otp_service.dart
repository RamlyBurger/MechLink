import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class OTPService {
  // Private constructor
  OTPService._();

  // Singleton instance
  static final OTPService _instance = OTPService._();

  // Factory constructor to return the singleton instance
  factory OTPService() => _instance;

  // EmailJS configuration
  static const String _serviceId = 'service_zpq6hiq';
  static const String _templateId = 'template_8fwmtym';
  static const String _userId = '339OA9HbbIoQkU7Ze';
  static const String _emailJSUrl = 'https://api.emailjs.com/api/v1.0/email/send';

  // OTP storage and management
  final Map<String, _OTPData> _otpStorage = {};

  // Generate and send OTP
  Future<String?> generateAndSendOTP({
    required String email,
    required String userName,
    int expirationMinutes = 5,
  }) async {
    try {
      // Generate 4-digit OTP
      final random = Random();
      final otp = (1000 + random.nextInt(9000)).toString();
      
      // Store OTP with expiration
      _otpStorage[email] = _OTPData(
        otp: otp,
        generatedAt: DateTime.now(),
        expirationMinutes: expirationMinutes,
      );

      debugPrint('📧 Generating OTP: $otp for $email');

      // Send OTP via EmailJS
      final success = await _sendOTPEmail(
        email: email,
        userName: userName,
        otp: otp,
        expirationMinutes: expirationMinutes,
      );

      if (success) {
        debugPrint('✅ OTP sent successfully to $email');
        return otp;
      } else {
        // Remove OTP if email failed
        _otpStorage.remove(email);
        debugPrint('❌ Failed to send OTP email to $email');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error generating/sending OTP: $e');
      return null;
    }
  }

  // Verify OTP
  bool verifyOTP({
    required String email,
    required String enteredOTP,
  }) {
    final otpData = _otpStorage[email];
    
    if (otpData == null) {
      debugPrint('❌ No OTP found for $email');
      return false;
    }

    // Check if OTP has expired
    final now = DateTime.now();
    final expirationTime = otpData.generatedAt.add(
      Duration(minutes: otpData.expirationMinutes),
    );

    if (now.isAfter(expirationTime)) {
      debugPrint('❌ OTP expired for $email');
      _otpStorage.remove(email);
      return false;
    }

    // Verify OTP
    final isValid = otpData.otp == enteredOTP;
    
    if (isValid) {
      debugPrint('✅ OTP verified successfully for $email');
      // Remove OTP after successful verification
      _otpStorage.remove(email);
    } else {
      debugPrint('❌ Invalid OTP for $email');
    }

    return isValid;
  }

  // Check if OTP exists and is valid for email
  bool hasValidOTP(String email) {
    final otpData = _otpStorage[email];
    if (otpData == null) return false;

    final now = DateTime.now();
    final expirationTime = otpData.generatedAt.add(
      Duration(minutes: otpData.expirationMinutes),
    );

    return now.isBefore(expirationTime);
  }

  // Get remaining time for OTP
  int getRemainingSeconds(String email) {
    final otpData = _otpStorage[email];
    if (otpData == null) return 0;

    final now = DateTime.now();
    final expirationTime = otpData.generatedAt.add(
      Duration(minutes: otpData.expirationMinutes),
    );

    if (now.isAfter(expirationTime)) {
      return 0;
    }

    return expirationTime.difference(now).inSeconds;
  }

  // Send OTP email via EmailJS
  Future<bool> _sendOTPEmail({
    required String email,
    required String userName,
    required String otp,
    required int expirationMinutes,
  }) async {
    try {
      debugPrint('📧 Sending OTP to $email via EmailJS...');

      final data = {
        'service_id': _serviceId,
        'template_id': _templateId,
        'user_id': _userId,
        'template_params': {
          'passcode': otp,
          'time': '${expirationMinutes}min',
          'email': email,
          'to_email': email,
          'subject': 'MechLink - OTP Verification Code',
          'message': 'Your OTP verification code is: $otp. This code will expire in $expirationMinutes minutes.',
        },
      };

      debugPrint('📤 EmailJS request data: ${jsonEncode(data)}');

      final response = await http.post(
        Uri.parse(_emailJSUrl),
        headers: {
          'Content-Type': 'application/json',
          'Origin': 'https://mechlink.com',
        },
        body: jsonEncode(data),
      );

      debugPrint('📬 EmailJS response status: ${response.statusCode}');
      debugPrint('📬 EmailJS response body: ${response.body}');

      if (response.statusCode == 200) {
        debugPrint('✅ OTP email sent successfully to $email');
        return true;
      } else {
        debugPrint('❌ Failed to send OTP email. Status: ${response.statusCode}');
        debugPrint('❌ Response: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error sending OTP email: $e');
      return false;
    }
  }

  // Send password change confirmation email
  Future<bool> sendPasswordChangeConfirmation({
    required String email,
    required String userName,
  }) async {
    try {
      debugPrint('📧 Sending password change confirmation to $email...');

      final data = {
        'service_id': _serviceId,
        'template_id': _templateId,
        'user_id': _userId,
        'template_params': {
          'passcode': 'N/A',
          'time': 'N/A',
          'email': email,
          'to_email': email,
          'subject': 'MechLink - Password Changed Successfully',
          'message': 'Hello $userName,\n\nYour password has been successfully changed. If you did not make this change, please contact support immediately.',
        },
      };

      final response = await http.post(
        Uri.parse(_emailJSUrl),
        headers: {
          'Content-Type': 'application/json',
          'Origin': 'https://mechlink.com',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Password change confirmation sent to $email');
        return true;
      } else {
        debugPrint('❌ Failed to send confirmation email. Status: ${response.statusCode}');
        debugPrint('❌ Response: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error sending confirmation email: $e');
      return false;
    }
  }

  // Clear OTP for email (useful for cleanup)
  void clearOTP(String email) {
    _otpStorage.remove(email);
  }

  // Clear all expired OTPs
  void clearExpiredOTPs() {
    final now = DateTime.now();
    _otpStorage.removeWhere((email, otpData) {
      final expirationTime = otpData.generatedAt.add(
        Duration(minutes: otpData.expirationMinutes),
      );
      return now.isAfter(expirationTime);
    });
  }
}

// Internal class to store OTP data
class _OTPData {
  final String otp;
  final DateTime generatedAt;
  final int expirationMinutes;

  _OTPData({
    required this.otp,
    required this.generatedAt,
    required this.expirationMinutes,
  });
}
