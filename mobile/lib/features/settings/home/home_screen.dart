import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Presensi Wajah'),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: () => context.push('/settings'))
        ],
      ),
      body: const Center(child: Text('Daftar Kelas akan muncul di sini nanti.')),
    );
  }
}