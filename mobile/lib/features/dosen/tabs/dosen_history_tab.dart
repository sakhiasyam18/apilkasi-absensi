import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/luxury_card.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/status_badge.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/models/session_model.dart';

class DosenHistoryTab extends ConsumerStatefulWidget {
  const DosenHistoryTab({super.key});

  @override
  ConsumerState<DosenHistoryTab> createState() => _DosenHistoryTabState();
}

class _DosenHistoryTabState extends ConsumerState<DosenHistoryTab> {
  int _selectedFilterIndex = 0; // 0: Semua, 1: Selesai, 2: Berlangsung
  final List<String> _filters = ['Semua', 'Selesai', 'Berlangsung'];
  int _selectedDay = 2; // Default to 2 November

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(allSessionsProvider);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.cardSurface,
          onRefresh: () async {
            ref.invalidate(allSessionsProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                const Text(
                  'Riwayat Presensi',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Pantau seluruh rekapitulasi kehadiran dan sesi perkuliahan',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),

                // Month Navigator & Date Strip
                _buildMonthCalendarStrip(),
                const SizedBox(height: 20),

                // Status Filter Chips
                _buildFilterChips(),
                const SizedBox(height: 18),

                // Sessions List or Zero-State
                sessionsAsync.when(
                  data: (sessions) {
                    var filtered = sessions;
                    if (_selectedFilterIndex == 1) {
                      filtered = filtered.where((s) => s.status == 'final').toList();
                    } else if (_selectedFilterIndex == 2) {
                      filtered = filtered.where((s) => s.status != 'final').toList();
                    }

                    if (filtered.isEmpty) {
                      return LuxuryCard(
                        padding: const EdgeInsets.all(28),
                        child: EmptyStateView(
                          icon: Icons.history_rounded,
                          title: 'Belum Ada Riwayat Sesi',
                          message:
                              'Tidak ada sesi presensi yang tercatat pada filter ini. Data saat ini bersih & kosong (0 sesi).',
                          buttonText: 'Mulai Presensi Baru',
                          buttonIcon: Icons.camera_alt_rounded,
                          onButtonPressed: () => context.push('/attendance'),
                        ),
                      );
                    }

                    return Column(
                      children: filtered
                          .map((sess) => _buildSessionCard(context, sess))
                          .toList(),
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  ),
                  error: (err, _) => LuxuryCard(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'Gagal memuat sesi: $err',
                        style: const TextStyle(color: AppColors.alpa),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthCalendarStrip() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgNavy,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          // Month header with arrows
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'November 2026',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border, width: 1),
                    ),
                    child: const Icon(Icons.chevron_left_rounded, size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border, width: 1),
                    ),
                    child: const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Horizontal Date Strip (1 to 7 Nov)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDateItem(day: 1, dayName: 'Min'),
              _buildDateItem(day: 2, dayName: 'Sen'),
              _buildDateItem(day: 3, dayName: 'Sel'),
              _buildDateItem(day: 4, dayName: 'Rab'),
              _buildDateItem(day: 5, dayName: 'Kam'),
              _buildDateItem(day: 6, dayName: 'Jum'),
              _buildDateItem(day: 7, dayName: 'Sab'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateItem({required int day, required String dayName}) {
    final isSelected = _selectedDay == day;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedDay = day);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.cardSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryLight : AppColors.border,
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Text(
              dayName,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$day',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: List.generate(_filters.length, (index) {
          final isSelected = _selectedFilterIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(_filters[index]),
              selected: isSelected,
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.cardSurface,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: 1,
                ),
              ),
              onSelected: (_) {
                setState(() => _selectedFilterIndex = index);
              },
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSessionCard(BuildContext context, SessionData sess) {
    final isFinal = sess.status == 'final';
    final progress = sess.progress;
    final total = progress?.totalParticipants ?? sess.participants.length;
    final present = progress?.identified.length ?? 0;
    final percentage = total > 0 ? (present / total) : 0.0;

    return LuxuryCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () {
        context.push('/session/${sess.id}', extra: sess);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.bgDark,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Pertemuan ${sess.meetingNumber}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryLight,
                  ),
                ),
              ),
              StatusBadge(
                status: isFinal ? 'Selesai' : 'Berlangsung',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            sess.activityName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                sess.sessionDate,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.access_time_rounded, size: 13, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                sess.sessionTime,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Attendance Progress Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Kehadiran: $present/$total Mahasiswa',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '${(percentage * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percentage.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: AppColors.cardSurfaceHover,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
