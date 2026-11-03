import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/settings_repository.dart';
import '../models/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.watch(apiClientProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return AuthRepository(dio, prefs);
});

class AuthRepository {
  final Dio _dio;
  final SharedPreferences _prefs;

  AuthRepository(this._dio, this._prefs);

  static const String _userSessionKey = 'user_session_v2';

  UserModel? getSavedUser() {
    final raw = _prefs.getString(_userSessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return UserModel.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveUser(UserModel user) async {
    await _prefs.setString(_userSessionKey, jsonEncode(user.toJson()));
  }

  Future<void> clearUser() async {
    await _prefs.remove(_userSessionKey);
  }

  Future<UserModel> login({required String email, required String password}) async {
    final response = await _dio.post(
      '/auth/login',
      data: {
        'email': email.trim(),
        'password': password,
      },
    );
    final user = UserModel.fromJson(response.data as Map<String, dynamic>);
    await saveUser(user);
    return user;
  }

  Future<UserModel> register({
    required String email,
    required String password,
    required String fullName,
    String? identifier,
    String role = 'dosen',
    String? programStudy,
  }) async {
    final response = await _dio.post(
      '/auth/register',
      data: {
        'email': email.trim(),
        'password': password,
        'full_name': fullName.trim(),
        'identifier': identifier?.trim(),
        'role': role,
        'program_study': programStudy?.trim(),
      },
    );
    final user = UserModel.fromJson(response.data as Map<String, dynamic>);
    await saveUser(user);
    return user;
  }
}
