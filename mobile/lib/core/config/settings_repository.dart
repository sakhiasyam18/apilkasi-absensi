import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Provider untuk SharedPreferences yang akan diinisialisasi di main.dart
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider belum diinisialisasi');
});

// Provider untuk SettingsRepository
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsRepository(prefs);
});

class SettingsRepository {
  final SharedPreferences _prefs;
  static const _baseUrlKey = 'backend_base_url';

  SettingsRepository(this._prefs);

  // Mengambil URL yang tersimpan, atau nilai default jika belum ada
  String get baseUrl => _prefs.getString(_baseUrlKey) ?? 'http://192.168.1.100:8000';

  // Menyimpan URL baru yang diinput oleh dosen
  Future<void> setBaseUrl(String url) async {
    // Hilangkan slash di akhir URL jika ada agar formatnya konsisten
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    await _prefs.setString(_baseUrlKey, url);
  }
}