import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../core/config/settings_repository.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/luxury_card.dart';
import '../../core/widgets/primary_button.dart';
import '../classes/data/classes_repository.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _urlController = TextEditingController();
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _urlController.text = ref.read(settingsRepositoryProvider).baseUrl;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() => _isTesting = true);
    await ref.read(settingsRepositoryProvider).setBaseUrl(_urlController.text);
    ref.invalidate(apiClientProvider);
    try {
      final dio = ref.read(apiClientProvider);
      final response = await dio.get('/health');
      if (mounted) {
        ref.invalidate(classesListProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Koneksi Berhasil! Status: ${response.data['status']} • Model: ${response.data['model_loaded']}'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Koneksi Gagal: ${e.message}'),
            backgroundColor: AppColors.alpa,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTesting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: const Text('Pengaturan Server & IP'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Konfigurasi Backend InsightFace',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Pastikan alamat IP komputer server FastAPI dan port 8000 dapat diakses melalui jaringan Wi-Fi lokal yang sama.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 20),

            LuxuryCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Alamat URL Server',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _urlController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'http://192.168.1.32:8000',
                      prefixIcon: const Icon(Icons.dns_rounded, color: AppColors.textMuted, size: 20),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.textMuted, size: 18),
                        onPressed: () => _urlController.clear(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  PrimaryButton(
                    text: 'Simpan & Tes Koneksi',
                    icon: Icons.wifi_tethering_rounded,
                    isLoading: _isTesting,
                    onPressed: _testConnection,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Pilihan Cepat (Presets)',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),

            // Wi-Fi Preset (Recommended)
            LuxuryCard(
              margin: const EdgeInsets.only(bottom: 12),
              onTap: () {
                _urlController.text = 'http://192.168.1.32:8000';
                _testConnection();
              },
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.wifi_rounded, color: AppColors.primaryLight, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Wi-Fi Laptop (192.168.1.32)',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'http://192.168.1.32:8000 (Mode Nirkabel/Tanpa Kabel)',
                          style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.primaryLight),
                ],
              ),
            ),

            // USB ADB Reverse Preset
            LuxuryCard(
              margin: const EdgeInsets.only(bottom: 12),
              onTap: () {
                _urlController.text = 'http://127.0.0.1:8000';
                _testConnection();
              },
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.usb_rounded, color: AppColors.secondary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Koneksi USB / Localhost',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'http://127.0.0.1:8000 (Via ADB Reverse Kabel USB)',
                          style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 1),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.primaryLight, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Sistem V2 telah dikonfigurasi untuk bekerja optimal melalui jaringan Wi-Fi lokal sehingga HP tidak perlu dicolokkan ke kabel USB saat digunakan di ruang kelas.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
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