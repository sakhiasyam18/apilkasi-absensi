import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../core/config/settings_repository.dart';
import '../../core/api/api_client.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _urlController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Isi TextField dengan URL yang tersimpan saat ini
    _urlController.text = ref.read(settingsRepositoryProvider).baseUrl;
  }

  Future<void> _testConnection() async {
    setState(() => _isLoading = true);
    
    // Simpan URL baru sebelum dites
    await ref.read(settingsRepositoryProvider).setBaseUrl(_urlController.text);
    
    try {
      // Panggil endpoint GET /health menggunakan Dio
      final dio = ref.read(apiClientProvider);
      final response = await dio.get('/health');
      
      if (!mounted) return;
      
      // Jika berhasil, tampilkan Snackbar hijau
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Koneksi Berhasil! Status: ${response.data['status']}'),
          backgroundColor: Colors.green,
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      // Jika gagal, tampilkan Snackbar merah beserta pesannya
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Koneksi Gagal: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('URL Backend (Gunakan IP Laptopmu, misal: http://192.168.1.5:8000)'),
            const SizedBox(height: 8),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'http://192.168.x.x:8000',
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _testConnection,
              child: _isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Simpan & Tes Koneksi'),
            ),
          ],
        ),
      ),
    );
  }
}