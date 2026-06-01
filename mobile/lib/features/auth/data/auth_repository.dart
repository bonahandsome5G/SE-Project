import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/api_client.dart';
import '../../../core/services/supabase_service.dart';

class UserProfile {
  const UserProfile({
    required this.role,
    required this.isBlocked,
  });

  final String role;
  final bool isBlocked;

  bool get isCitizen => role == 'citizen';
}

class AuthRepository {
  final SupabaseClient _client = SupabaseService.client;
  final ApiClient _apiClient = ApiClient();

  User? get currentUser => _client.auth.currentUser;

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': name},
    );
  }

  Future<User> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final user = response.user;
    if (user == null) {
      throw const AuthException('Login gagal. Silakan coba lagi.');
    }

    return user;
  }

  Future<UserProfile> getProfile(String userId) async {
    final data = await _apiClient.get('/citizen/me') as Map<String, dynamic>;

    return UserProfile(
      role: data['role'] as String? ?? 'citizen',
      isBlocked: false,
    );
  }

  Future<void> signOut() => _client.auth.signOut();
}
