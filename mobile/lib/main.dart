import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/router.dart';
import 'core/config/settings_repository.dart';

void main() async {
  // Wajib dipanggil sebelum inisialisasi plugin native (seperti SharedPreferences)
  WidgetsFlutterBinding.ensureInitialized();
  
  // Tunggu penyimpanan lokal siap sebelum aplikasi dirender
  final prefs = await SharedPreferences.getInstance();

  runApp(
    // ProviderScope membungkus seluruh aplikasi agar Riverpod bisa digunakan
    ProviderScope(
      overrides: [
        // Mengisi provider yang tadinya kosong (di settings_repository.dart) dengan instance asli
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Aplikasi Presensi',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      routerConfig: appRouter, // Hubungkan MaterialApp dengan go_router
    );
  }
}