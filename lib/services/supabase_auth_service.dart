import 'package:supabase_flutter/supabase_flutter.dart';

/// A service to manage authentication using Supabase Auth.
class SupabaseAuthService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Gets the currently authenticated user.
  User? get currentUser => _client.auth.currentUser;

  /// Registers a new user with an email, password, and custom metadata (e.g., name).
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: {'name': name},
    );
  }

  /// Logs in an existing user with email and password.
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Signs the current user out of Supabase.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
