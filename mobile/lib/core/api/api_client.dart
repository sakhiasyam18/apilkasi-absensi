import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/settings_repository.dart';

// Provider ini akan menyediakan instance Dio yang sudah dikonfigurasi
// ke seluruh bagian aplikasi yang membutuhkannya.
final apiClientProvider = Provider<Dio>((ref) {
  // Ambil pengaturan URL dari repository yang kita buat sebelumnya
  final settings = ref.watch(settingsRepositoryProvider);

  final dio = Dio(BaseOptions(
    baseUrl: settings.baseUrl,
    // Timeout koneksi 10 detik dan receive 60 detik sesuai dokumen spesifikasi.
    // Receive butuh waktu lama karena proses AI deteksi wajah di backend butuh waktu komputasi.
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 60),
  ));

  // (Opsional tapi penting) Menambahkan interceptor untuk log error di terminal
  dio.interceptors.add(LogInterceptor(responseBody: true, requestBody: true));

  return dio;
});