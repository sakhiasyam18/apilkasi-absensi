import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../core/config/settings_repository.dart';
import '../../core/api/api_client.dart';
import '../classes/data/classes_repository.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _urlController.text = ref.read(settingsRepositoryProvider).baseUrl;
  }

  Future<void> _testConnection() async {
    await ref.read(settingsRepositoryProvider).setBaseUrl(_urlController.text);
    ref.invalidate(apiClientProvider);
    try {
      final dio = ref.read(apiClientProvider);
      final response = await dio.get('/health');
      if (mounted) {
        ref.invalidate(classesListProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Koneksi Berhasil! Status: ${response.data['status']}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Koneksi Gagal: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Server'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Alamat URL Backend',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'URL Server Backend',
                hintText: 'http://127.0.0.1:8000',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.dns_outlined),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Simpan & Tes Koneksi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: _testConnection,
            ),
            const SizedBox(height: 24),
            const Text(
              'Pilihan Cepat (Presets):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: Colors.blue.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: ListTile(
                leading: const Icon(Icons.usb, color: Colors.indigo),
                title: const Text('Koneksi USB (Direkomendasikan)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('http://127.0.0.1:8000 (Via ADB Reverse USB)'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  _urlController.text = 'http://127.0.0.1:8000';
                  _testConnection();
                },
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: Colors.grey.shade100,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: ListTile(
                leading: const Icon(Icons.wifi, color: Colors.blueGrey),
                title: const Text('Koneksi Wi-Fi Lokal', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('http://10.123.42.1:8000 (IP Wi-Fi Laptop)'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  _urlController.text = 'http://10.123.42.1:8000';
                  _testConnection();
                },
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.amber, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Jika HP tersambung ke laptop dengan kabel USB, pilih "Koneksi USB (127.0.0.1:8000)" karena lebih stabil dan tidak memerlukan koneksi internet/Wi-Fi yang sama.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}