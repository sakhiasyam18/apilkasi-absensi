import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/upload_queue/queue_worker.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Memastikan background queue worker aktif sejak aplikasi dibuka
    ref.watch(queueWorkerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Presensi Wajah'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Pengaturan Server',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const Center(
                child: Icon(Icons.school, size: 64, color: Colors.indigo),
              ),
              const SizedBox(height: 12),
              const Text(
                'Sistem Presensi Otomatis',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Pengenalan Wajah AI InsightFace & Google ML Kit',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 24),

              // Menu 1: Mulai Presensi Kelas (Primary)
              _MenuCard(
                icon: Icons.camera_enhance,
                iconColor: Colors.deepPurple,
                title: 'Mulai Presensi Kelas',
                subtitle: 'Buka sesi baru untuk memotret kehadiran mahasiswa',
                onTap: () => context.push('/attendance'),
              ),
              const SizedBox(height: 12),

              // Menu 2: Kelola Kelas & Roster
              _MenuCard(
                icon: Icons.meeting_room_outlined,
                iconColor: Colors.indigo,
                title: 'Manajemen Kelas & Roster',
                subtitle: 'Daftar kelas, import CSV mahasiswa, dan status wajah',
                onTap: () => context.push('/classes'),
              ),
              const SizedBox(height: 12),

              // Menu 3: Registrasi Wajah
              _MenuCard(
                icon: Icons.face_retouching_natural,
                iconColor: Colors.teal,
                title: 'Registrasi Wajah Mahasiswa',
                subtitle: 'Verifikasi NIM & panduan pengambilan 5 pose foto',
                onTap: () => context.push('/register'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: iconColor.withValues(alpha: 0.12),
                foregroundColor: iconColor,
                child: Icon(icon, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
