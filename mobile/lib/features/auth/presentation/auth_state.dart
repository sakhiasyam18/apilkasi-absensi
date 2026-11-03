import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../models/user_model.dart';

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? errorMessage;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
  });

  bool get isAuthenticated => user != null;
  bool get isDosen => user?.isDosen ?? false;
  bool get isMahasiswa => user?.isMahasiswa ?? false;

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  late final AuthRepository _repo;

  @override
  AuthState build() {
    _repo = ref.watch(authRepositoryProvider);
    final saved = _repo.getSavedUser();
    return AuthState(user: saved);
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = await _repo.login(email: email, password: password);
      state = state.copyWith(user: user, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal masuk: Periksa koneksi backend atau kredensial Anda.',
      );
      return false;
    }
  }

  Future<void> loginAsDefaultDosen() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = await _repo.login(
        email: 'ashar.pakawaru@um.ac.id',
        password: 'password123',
      );
      state = state.copyWith(user: user, isLoading: false);
    } catch (_) {
      // Fallback offline mock for immediate visual inspection if server is uncontactable
      final fallbackUser = UserModel.defaultDosen();
      await _repo.saveUser(fallbackUser);
      state = state.copyWith(user: fallbackUser, isLoading: false);
    }
  }

  Future<void> loginAsDefaultMahasiswa() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = await _repo.login(
        email: 'allen.sebastian@um.ac.id',
        password: 'password123',
      );
      state = state.copyWith(user: user, isLoading: false);
    } catch (_) {
      final fallbackUser = UserModel.defaultMahasiswa();
      await _repo.saveUser(fallbackUser);
      state = state.copyWith(user: fallbackUser, isLoading: false);
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
    String? identifier,
    String role = 'dosen',
    String? programStudy,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = await _repo.register(
        email: email,
        password: password,
        fullName: fullName,
        identifier: identifier,
        role: role,
        programStudy: programStudy,
      );
      state = state.copyWith(user: user, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal mendaftar: Email mungkin sudah terdaftar.',
      );
      return false;
    }
  }

  Future<void> logout() async {
    await _repo.clearUser();
    state = const AuthState(user: null);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
