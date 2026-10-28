import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'data/attendance_repository.dart';
import 'models/session_model.dart';

class SessionHomeScreen extends ConsumerWidget {
  final int sessionId;
  final SessionData? initialSession;

  const SessionHomeScreen({
    super.key,
    required this.sessionId,
    this.initialSession,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sessionDetailProvider(sessionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sesi Presensi Aktif'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Segarkan Data',
            onPressed: () => ref.invalidate(sessionDetailProvider(sessionId)),
          ),
        ],
      ),
      body: sessionAsync.when(
        data: (session) => _buildSessionContent(context, ref, session),
        loading: () {
          if (initialSession != null) {
            return _buildSessionContent(context, ref, initialSession!);
          }
          return const Center(child: CircularProgressIndicator());
        },
        error: (err, _) {
          if (initialSession != null) {
            return _buildSessionContent(context, ref, initialSession!);
          }
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 12),
                  Text('Gagal memuat sesi: $err'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(sessionDetailProvider(sessionId)),
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSessionContent(BuildContext context, WidgetRef ref, SessionData session) {
    return Column(
      children: [
        // 1. Info Card Sesi
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.indigo.shade50,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      session.activityName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.indigo,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Pertemuan ${session.meetingNumber}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(session.sessionDate, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                  const SizedBox(width: 14),
                  const Icon(Icons.access_time, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(session.sessionTime, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                  const Spacer(),
                  const Icon(Icons.camera_alt_outlined, size: 14, color: Colors.indigo),
                  const SizedBox(width: 4),
                  Text(
                    'Capture: ${session.captureCount} / ${session.maxCaptures}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo),
                  ),
                ],
              ),
              if (session.withoutFacesCount > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.warning_amber, size: 16, color: Colors.orange),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Ada ${session.withoutFacesCount} peserta yang belum mendaftarkan wajah.',
                        style: TextStyle(color: Colors.orange.shade900, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // 2. Daftar Peserta
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daftar Peserta (${session.participants.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              Text(
                'Status Hadir',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: session.participants.length,
            itemBuilder: (context, index) {
              final p = session.participants[index];
              return Card(
                elevation: 0.5,
                margin: const EdgeInsets.only(bottom: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: p.hasFaces ? Colors.green.shade50 : Colors.grey.shade100,
                    foregroundColor: p.hasFaces ? Colors.green.shade700 : Colors.grey.shade600,
                    child: Text('${index + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(p.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text('NIM: ${p.nim}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('Belum Hadir', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ),
                ),
              );
            },
          ),
        ),

        // 3. Bottom Action Bar
        SafeArea(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  offset: const Offset(0, -2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Ambil Foto Presensi'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      context.push('/session/${session.id}/capture');
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
