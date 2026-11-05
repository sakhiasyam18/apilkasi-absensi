import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/luxury_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../auth/presentation/auth_state.dart';
import '../../classes/data/classes_repository.dart';
import '../../attendance/data/attendance_repository.dart';

class MahasiswaHomeTab extends ConsumerStatefulWidget {
  final VoidCallback? onNavigateToHistory;

  const MahasiswaHomeTab({
    super.key,
    this.onNavigateToHistory,
  });

  @override
  ConsumerState<MahasiswaHomeTab> createState() => _MahasiswaHomeTabState();
}

class _MahasiswaHomeTabState extends ConsumerState<MahasiswaHomeTab> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final classesAsync = ref.watch(classesListProvider);
    final sessionsAsync = ref.watch(allSessionsProvider);

    final studentName = user?.fullName.isNotEmpty == true ? user!.fullName : 'Mahasiswa';
    final studentNim = user?.identifier?.isNotEmpty == true ? user!.identifier! : '-';
    final userNim = user?.identifier?.trim() ?? '';

    // Perhitungan Kehadiran Dinamis (Default Kosong = 0)
    int hadirCount = 0;
    int sakitCount = 0;
    int izinCount = 0;
    int alpaCount = 0;
    int totalCount = 0;

    sessionsAsync.whenData((sessions) {
      if (userNim.isNotEmpty) {
        for (final sess in sessions) {
          final isIdentified = sess.progress?.identified.any((p) => p.nim == userNim) ?? false;
          final isParticipant = sess.participants.any((p) => p.nim == userNim);

          if (isIdentified) {
            hadirCount++;
            totalCount++;
          } else if (isParticipant && sess.status == 'final') {
            alpaCount++;
            totalCount++;
          }
        }
      }
    });

    final double attendanceRatio = totalCount > 0 ? (hadirCount / totalCount) : 0.0;
    final int attendancePercent = (attendanceRatio * 100).round();

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.cardSurface,
          onRefresh: () async {
            ref.invalidate(classesListProvider);
            ref.invalidate(allSessionsProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(context),
                const SizedBox(height: 20),
                _buildGreetingCard(studentName, studentNim),
                const SizedBox(height: 24),
                _buildLaporanKehadiran(
                  percent: attendancePercent,
                  ratio: attendanceRatio,
                  hadir: hadirCount,
                  sakit: sakitCount,
                  izin: izinCount,
                  alpa: alpaCount,
                ),
                const SizedBox(height: 28),
                _buildSectionHeader('Kelas Hari Ini'),
                const SizedBox(height: 14),
                _buildTodayClasses(classesAsync),
                const SizedBox(height: 28),
                _buildSectionHeader('History Terbaru', onViewAll: widget.onNavigateToHistory),
                const SizedBox(height: 14),
                _buildRecentHistory(sessionsAsync, userNim),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
              ),
              child: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'SnapAttend',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_none_rounded, color: AppColors.textPrimary, size: 20),
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGreetingCard(String name, String nim) {
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.cardSurface,
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.person_rounded, size: 36, color: AppColors.primary),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Good Morning',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border, width: 1),
                    ),
                    child: Text(
                      'NIM $nim',
                      style: const TextStyle(
                        color: AppColors.primaryLight,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLaporanKehadiran({
    required int percent,
    required double ratio,
    required int hadir,
    required int sakit,
    required int izin,
    required int alpa,
  }) {
    return LuxuryCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Laporan Kehadiran',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              // Circular Donut Progress
              Expanded(
                flex: 4,
                child: Center(
                  child: SizedBox(
                    width: 110,
                    height: 110,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 100,
                          height: 100,
                          child: CircularProgressIndicator(
                            value: ratio,
                            strokeWidth: 10,
                            backgroundColor: AppColors.border,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              ratio > 0 ? AppColors.hadir : AppColors.textMuted.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$percent%',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Text(
                              'Kehadiran',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // 2x2 Stat Cards
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildMiniStat(label: 'Hadir', count: '$hadir', color: AppColors.hadir)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildMiniStat(label: 'Sakit', count: '$sakit', color: AppColors.sakit)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _buildMiniStat(label: 'Izin', count: '$izin', color: AppColors.izin)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildMiniStat(label: 'Alpa', count: '$alpa', color: AppColors.alpa)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat({required String label, required String count, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Column(
        children: [
          Text(
            count,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.9),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onViewAll}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        if (onViewAll != null)
          GestureDetector(
            onTap: onViewAll,
            child: const Text(
              'Lihat Semua',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTodayClasses(AsyncValue classesAsync) {
    return classesAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (err, stack) => _buildEmptyClasses(),
      data: (classes) {
        if (classes.isEmpty) {
          return _buildEmptyClasses();
        }

        return Column(
          children: classes.take(3).map<Widget>((cls) {
            final codeLabel = cls.code?.isNotEmpty == true ? cls.code! : (cls.scheduleDay ?? 'Kelas');
            final roomLabel = cls.room?.isNotEmpty == true ? cls.room! : 'Ruang Kelas';
            final timeLabel = cls.scheduleTime?.isNotEmpty == true ? cls.scheduleTime! : 'Jadwal Perkuliahan';

            return LuxuryCard(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          cls.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1),
                        ),
                        child: Text(
                          codeLabel,
                          style: const TextStyle(
                            color: AppColors.primaryLight,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        roomLabel,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.schedule_rounded, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        timeLabel,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildEmptyClasses() {
    return const EmptyStateView(
      icon: Icons.calendar_today_rounded,
      title: 'Belum Ada Jadwal Kelas Hari Ini',
      message: 'Jadwal perkuliahan akan muncul otomatis saat kelas aktif dibuka oleh Dosen.',
    );
  }

  Widget _buildRecentHistory(AsyncValue sessionsAsync, String userNim) {
    return sessionsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => _buildEmptyHistory(),
      data: (sessions) {
        // Ambil sesi yang relevan dengan mahasiswa ini
        final userSessions = sessions.where((sess) {
          if (userNim.isEmpty) return true;
          final isIdentified = sess.progress?.identified.any((p) => p.nim == userNim) ?? false;
          final isParticipant = sess.participants.any((p) => p.nim == userNim);
          return isIdentified || isParticipant;
        }).toList();

        if (userSessions.isEmpty) {
          return _buildEmptyHistory();
        }

        return Column(
          children: userSessions.take(3).map<Widget>((sess) {
            final isIdentified = userNim.isNotEmpty &&
                (sess.progress?.identified.any((p) => p.nim == userNim) ?? false);
            final statusStr = isIdentified
                ? 'hadir'
                : (sess.status == 'final' ? 'alpa' : 'belum');
            final badgeColor = isIdentified
                ? AppColors.hadir
                : (sess.status == 'final' ? AppColors.alpa : AppColors.textMuted);

            return LuxuryCard(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: badgeColor.withValues(alpha: 0.4), width: 1),
                    ),
                    child: Icon(
                      isIdentified
                          ? Icons.check_rounded
                          : (sess.status == 'final'
                              ? Icons.close_rounded
                              : Icons.hourglass_top_rounded),
                      color: badgeColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sess.activityName.isNotEmpty ? sess.activityName : 'Presensi Kuliah',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          sess.sessionDate.isNotEmpty ? sess.sessionDate : 'Hari Ini',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(status: statusStr),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
  Widget _buildEmptyHistory() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.history_toggle_off_rounded, color: AppColors.textMuted.withValues(alpha: 0.6), size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Belum ada riwayat presensi yang tercatat.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

