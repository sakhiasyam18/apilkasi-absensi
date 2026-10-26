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

  @override
  void initState() {
    super.initState();
    _urlController.text = ref.read(settingsRepositoryProvider).baseUrl;
  }

  Future<void> _testConnection() async {
    await ref.read(settingsRepositoryProvider).setBaseUrl(_urlController.text);
    try {
      final dio = ref.read(apiClientProvider);
      final response = await dio.get('/health');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Koneksi Berhasil! Status: ${response.data['status']}'), backgroundColor: Colors.green),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Koneksi Gagal: ${e.message}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _urlController, decoration: const InputDecoration(labelText: 'URL Backend')),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _testConnection, child: const Text('Simpan & Tes Koneksi')),
          ],
        ),
      ),
    );
  }
}