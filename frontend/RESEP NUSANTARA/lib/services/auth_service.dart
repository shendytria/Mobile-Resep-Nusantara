import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  static const String tokenKey = 'auth_token';
  static const String userDataKey = 'user_data';
  static const String userIdKey = 'user_id';

  static Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tokenKey, token);
    print('Token saved to SharedPreferences: $token');
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(tokenKey);
    print('Retrieved token from SharedPreferences: $token');
    return token;
  }

  static Future<void> setUserData(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(userDataKey, jsonEncode(userData));
    await prefs.setString(userIdKey, userData['user_id'].toString());
    print('User data saved to SharedPreferences: $userData');
  }

  static Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString(userDataKey);

    if (userDataString == null) {
      print('No user data found in SharedPreferences');
      return null;
    }

    try {
      final userData = jsonDecode(userDataString) as Map<String, dynamic>;
      print('Retrieved user data: $userData');
      return userData;
    } catch (e) {
      print('Error parsing user data: $e');
      return null;
    }
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(userIdKey);
    print('Retrieved user ID: $userId');
    return userId;
  }

  static Future<void> clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tokenKey);
    await prefs.remove(userDataKey);
    await prefs.remove(userIdKey);
    print('Cleared auth data from SharedPreferences');
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    print('Is logged in: ${token != null}');
    return token != null;
  }

  static Future<void> logout() async {
    final token = await getToken();
    print('Attempting logout with token: $token');

    if (token != null) {
      try {
        final response = await http.post(
          Uri.parse(kIsWeb ? 'http://127.0.0.1:8000/api/logout' : 'http://10.0.2.2:8000/api/logout'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        );

        print('Logout response: ${response.statusCode} - ${response.body}');
      } catch (e) {
        print('Logout error: $e');
      }
    } else {
      print('No token found, skipping API logout');
    }

    await clearAuthData();
  }
}