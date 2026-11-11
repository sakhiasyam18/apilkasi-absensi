import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(sharedPreferencesProvider));
});

class SettingsRepository {
  final SharedPreferences _prefs;
  SettingsRepository(this._prefs);

  // Default otomatis ke Wi-Fi laptop aktif
  String get baseUrl {
    final saved = _prefs.getString('backend_base_url');
    if (saved == null ||
        saved.isEmpty ||
        saved == 'http://192.168.1.32:8000' ||
        saved == 'http://192.168.176.85:8000' ||
        saved == 'http://192.168.216.85:8000') {
      return 'http://10.210.65.85:8000';
    }
    return saved;
  }
  
  Future<void> setBaseUrl(String url) async {
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    await _prefs.setString('backend_base_url', url);
  }
}
