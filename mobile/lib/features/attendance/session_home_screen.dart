import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/error_utils.dart';
import 'data/attendance_repository.dart';
import 'models/session_model.dart';

class SessionHomeScreen extends ConsumerStatefulWidget {
  final int sessionId;
  final SessionData? initialSession;

  const SessionHomeScreen({
    super.key,
    required this.sessionId,
    this.initialSession,
  });

  @override
  ConsumerState<SessionHomeScreen> createState() => _SessionHomeScreenState();
}

class _SessionHomeScreenState extends ConsumerState<SessionHomeScreen> {
  bool _isFinalizing = false;

  void _showFinalizeDialog(SessionData session) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_clock, color: Colors.indigo),
            SizedBox(width: 8),
            Expanded(child: Text('Selesaikan Presensi?')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Menyelesaikan sesi akan mengunci kehadiran mahasiswa dan mencatat poin resmi.',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Perhitungan Poin:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  SizedBox(height: 4),
                  Text('• Hadir: +10 Poin', style: TextStyle(color: Colors.green, fontSize: 12)),
                  Text('• Tidak Hadir: -10 Poin', style: TextStyle(color: Colors.red, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              setState(() => _isFinalizing = true);
              try {
                final repo = ref.read(attendanceRepositoryProvider);
                await repo.finalizeSession(session.id);
                ref.invalidate(sessionDetailProvider(session.id));
                ref.invalidate(classPointsProvider(session.classId));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Presensi sesi berhasil difinalisasi!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } on DioException catch (e) {
                final msg = ErrorUtils.getErrorMessage(e, 'Gagal menyelesaikan sesi');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(msg), backgroundColor: Colors.red),
                  );
                }
              } finally {
                if (mounted) setState(() => _isFinalizing = false);
              }
            },
            child: const Text('Selesaikan & Kunci'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionDetailProvider(widget.sessionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sesi Presensi Kelas'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Segarkan Data',
            onPressed: () => ref.invalidate(sessionDetailProvider(widget.sessionId)),
          ),
        ],
      ),
      body: sessionAsync.when(
        data: (session) => _buildSessionContent(context, session),
        loading: () {
          if (widget.initialSession != null) {
            return _buildSessionContent(context, widget.initialSession!);
          }
          return const Center(child: CircularProgressIndicator());
        },
        error: (err, _) {
          if (widget.initialSession != null) {
            return _buildSessionContent(context, widget.initialSession!);
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
                    onPressed: () => ref.invalidate(sessionDetailProvider(widget.sessionId)),
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

  Widget _buildSessionContent(BuildContext context, SessionData session) {
    final isFinal = session.status == 'final';

    // Buat map kehadiran dari progress
    final identMap = <int, IdentifiedParticipant>{};
    if (session.progress != null) {
      for (final iden in session.progress!.identified) {
        identMap[iden.studentId] = iden;
      }
    }

    final hadirCount = identMap.length;
    final totalCount = session.participants.length;

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
                      color: isFinal ? Colors.teal : Colors.indigo,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isFinal ? 'Final • Selesai' : 'Pertemuan ${session.meetingNumber}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
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
              if (session.withoutFacesCount > 0 && !isFinal) ...[
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

        // 2. Header Daftar Peserta & Badge Ringkasan Hadir
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daftar Mahasiswa ($hadirCount / $totalCount Hadir)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              if (isFinal)
                TextButton.icon(
                  icon: const Icon(Icons.emoji_events, size: 16, color: Colors.amber),
                  label: const Text('Poin Kelas', style: TextStyle(fontSize: 12)),
                  onPressed: () => context.push('/classes/${session.classId}/points'),
                ),
            ],
          ),
        ),
        const Divider(height: 1),

        // 3. List Mahasiswa
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: session.participants.length,
            itemBuilder: (context, index) {
              final p = session.participants[index];
              final isIdentified = identMap.containsKey(p.studentId);
              final idenInfo = identMap[p.studentId];

              Color avatarBg = Colors.grey.shade100;
              Color avatarFg = Colors.grey.shade600;
              Color badgeBg = Colors.grey.shade100;
              Color badgeFg = Colors.grey.shade700;
              String badgeText = 'Belum Hadir';

              if (isIdentified) {
                if (idenInfo?.method == 'manual') {
                  avatarBg = Colors.blue.shade50;
                  avatarFg = Colors.blue.shade700;
                  badgeBg = Colors.blue.shade50;
                  badgeFg = Colors.blue.shade800;
                  badgeText = 'Hadir (Manual)';
                } else {
                  avatarBg = Colors.green.shade50;
                  avatarFg = Colors.green.shade700;
                  badgeBg = Colors.green.shade50;
                  badgeFg = Colors.green.shade800;
                  badgeText = 'Hadir (AI)';
                }
              }

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
                    backgroundColor: avatarBg,
                    foregroundColor: avatarFg,
                    child: Icon(
                      isIdentified ? Icons.check : (p.hasFaces ? Icons.face : Icons.person_outline),
                      size: 16,
                    ),
                  ),
                  title: Text(
                    p.fullName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  subtitle: Text(
                    'NIM: ${p.nim}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: badgeFg,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // 4. Bottom Action Bar
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
            child: isFinal
                ? ElevatedButton.icon(
                    icon: const Icon(Icons.emoji_events),
                    label: const Text('Lihat Papan Peringkat Poin Kelas'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => context.push('/classes/${session.classId}/points'),
                  )
                : Row(
                    children: [
                      if (session.captureCount > 0) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Selesaikan'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.indigo,
                              side: const BorderSide(color: Colors.indigo),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _isFinalizing ? null : () => _showFinalizeDialog(session),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        flex: session.captureCount > 0 ? 2 : 1,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.camera_alt),
                          label: Text(session.captureCount > 0 ? 'Foto Tambahan' : 'Ambil Foto Presensi'),
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
