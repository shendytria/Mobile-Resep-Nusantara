import 'dart:convert';
import 'package:http/http.dart' as http;

class TwoFactorAuthService {
  final String baseUrl = 'http://127.0.0.1:8000/api';

  // Added debug mode for testing
  final bool debugMode = true;

  // Generate a QR code and secret for a user
  Future<Map<String, dynamic>> generateSecret(int userId) async {
    // For debugging/development, return mock data if API not available
    if (debugMode) {
      print('DEBUG MODE: Generating mock 2FA secret for user $userId');
      // Add the explicit TOTP URI which we'll use for local QR generation
      final String secret = 'JBSWY3DPEHPK3PXP';
      final String totpUri = 'otpauth://totp/ResepNusantara:user$userId@example.com?secret=$secret&issuer=ResepNusantara&algorithm=SHA1&digits=6&period=30';

      return {
        'success': true,
        'message': 'Secret generated successfully',
        'data': {
          'secret': secret,
          'qr_code_url': 'https://chart.googleapis.com/chart?chs=200x200&cht=qr&chl=${Uri.encodeComponent(totpUri)}',
          'totp_uri': totpUri, // Add this field explicitly
        }
      };
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/generate-2fa-secret'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'user_id': userId,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'],
          'data': responseData['data'],
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to generate 2FA secret',
        };
      }
    } catch (e) {
      print('Error generating 2FA secret: ${e.toString()}');
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }

  // Verify and enable 2FA for a user
  Future<Map<String, dynamic>> verifyAndEnable2FA(int userId, String secret, String verificationCode) async {
    // For debugging/development, return mock data if API not available
    if (debugMode) {
      print('DEBUG MODE: Verifying 2FA code $verificationCode for user $userId');
      // Simulate successful verification for code "123456"
      if (verificationCode == "123456") {
        return {
          'success': true,
          'message': 'Two-Factor Authentication enabled successfully!',
          'data': {
            'is_enabled': true
          }
        };
      } else {
        return {
          'success': false,
          'message': 'Invalid verification code. Please try again.',
        };
      }
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/verify-2fa'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'user_id': userId,
          'secret': secret,
          'verification_code': verificationCode,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'],
          'data': responseData['data'],
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to enable 2FA',
        };
      }
    } catch (e) {
      print('Error verifying 2FA code: ${e.toString()}');
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }

  // Check if 2FA is enabled for a user
  Future<bool> is2FAEnabled(int userId) async {
    // For debugging/development, return mock data if API not available
    if (debugMode) {
      print('DEBUG MODE: Checking 2FA status for user $userId');
      // Store in shared prefs to simulate persistence
      // For demo, just return false to allow enabling
      return false;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/check-2fa-status/$userId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return responseData['data']['is_enabled'] ?? false;
      } else {
        print('Failed to check 2FA status: ${responseData['message']}');
        return false;
      }
    } catch (e) {
      print('Error checking 2FA status: ${e.toString()}');
      return false;
    }
  }

  // Disable 2FA for a user
  Future<bool> disable2FA(int userId) async {
    // For debugging/development, return mock data if API not available
    if (debugMode) {
      print('DEBUG MODE: Disabling 2FA for user $userId');
      return true;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/disable-2fa'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'user_id': userId,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return true;
      } else {
        print('Failed to disable 2FA: ${responseData['message']}');
        return false;
      }
    } catch (e) {
      print('Error disabling 2FA: ${e.toString()}');
      return false;
    }
  }
}