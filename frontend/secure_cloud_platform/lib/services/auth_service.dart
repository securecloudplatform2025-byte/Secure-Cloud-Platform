import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static const String baseUrl = 'http://localhost:8000';
  
  static Future<bool> isLoggedIn() async {
    return Supabase.instance.client.auth.currentUser != null;
  }

  static Future<AuthResponse> signup(String email, String name, String password) async {
    final response = await Supabase.instance.client.auth.signUp(
      email: email,
      password: password,
      data: {'name': name},
    );
    
    if (response.user == null) {
      throw Exception('Signup failed');
    }
    
    return response;
  }

  static Future<AuthResponse> signin(String email, String password) async {
    final response = await Supabase.instance.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    
    if (response.user == null) {
      throw Exception('Signin failed');
    }
    
    return response;
  }

  static Future<bool> googleAuth() async {
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.flutterquickstart://login-callback/',
      );
      return true;
    } catch (e) {
      throw Exception('Google auth failed: $e');
    }
  }

  static Future<void> logout() async {
    await Supabase.instance.client.auth.signOut();
  }

  static Future<String?> getToken() async {
    return Supabase.instance.client.auth.currentSession?.accessToken;
  }

  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }
}