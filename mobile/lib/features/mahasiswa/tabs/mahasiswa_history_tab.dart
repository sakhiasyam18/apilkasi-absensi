import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/luxury_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../attendance/data/attendance_repository.dart';

class MahasiswaHistoryTab extends ConsumerStatefulWidget {
  const MahasiswaHistoryTab({super.key});

  @override
  ConsumerState<MahasiswaHistoryTab> createState() => _MahasiswaHistoryTabState();
}

class _MahasiswaHistoryTabState extends ConsumerState<MahasiswaHistoryTab> {
  DateTime _currentMonth = DateTime(2026, 1, 1);
  DateTime _selectedDate = DateTime(2026, 1, 18);

  final List<String> _weekdays = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
  final List<String> _monthNames = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(allSessionsProvider);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 18),
              _buildCalendarCard(),
              const SizedBox(height: 24),
              _buildSelectedDateHeader(),
              const SizedBox(height: 14),
              _buildDateSessionsList(sessionsAsync),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1),
          ),
          child: const Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        const Text(
          'Riwayat Kehadiran',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarCard() {
    return LuxuryCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          // Month navigator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: _prevMonth,
                icon: const Icon(Icons.chevron_left_rounded, color: AppColors.textPrimary, size: 28),
                splashRadius: 20,
              ),
              Column(
                children: [
                  Text(
                    _monthNames[_currentMonth.month - 1],
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${_currentMonth.year}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: _nextMonth,
                icon: const Icon(Icons.chevron_right_rounded, color: AppColors.textPrimary, size: 28),
                splashRadius: 20,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 14),
          // Weekdays header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _weekdays.map((w) {
              return SizedBox(
                width: 36,
                child: Center(
                  child: Text(
                    w,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          // Days grid
          _buildDaysMatrix(),
        ],
      ),
    );
  }

  Widget _buildDaysMatrix() {
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday; // 1 = Monday
    final offset = firstWeekday - 1; // 0 to 6

    final totalCells = ((daysInMonth + offset) / 7).ceil() * 7;

    return Column(
      children: List.generate((totalCells / 7).ceil(), (rowIndex) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (colIndex) {
              final cellIndex = rowIndex * 7 + colIndex;
              final dayNum = cellIndex - offset + 1;

              if (dayNum < 1 || dayNum > daysInMonth) {
                return const SizedBox(width: 36, height: 36);
              }

              final isSelected = _selectedDate.year == _currentMonth.year &&
                  _selectedDate.month == _currentMonth.month &&
                  _selectedDate.day == dayNum;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDate = DateTime(_currentMonth.year, _currentMonth.month, dayNum);
                  });
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '$dayNum',
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : (colIndex >= 5 ? AppColors.textMuted : AppColors.textPrimary),
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  Widget _buildSelectedDateHeader() {
    final day = _selectedDate.day;
    final monthName = _monthNames[_selectedDate.month - 1];
    final year = _selectedDate.year;

    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$day $monthName $year',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildDateSessionsList(AsyncValue sessionsAsync) {
    return sessionsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (err, stack) => _buildEmptyDaySessions(),
      data: (sessions) {
        if (sessions.isEmpty) {
          return _buildEmptyDaySessions();
        }

        return Column(
          children: sessions.map<Widget>((sess) {
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
                          sess.name.isNotEmpty ? sess.name : 'Sesi Perkuliahan',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const StatusBadge(status: 'hadir'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      const Text(
                        'B12 - 201',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.schedule_rounded, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        sess.createdAt.isNotEmpty ? sess.createdAt.split('T').last.substring(0, 5) : '07:00 - 09.35',
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

  Widget _buildEmptyDaySessions() {
    return const EmptyStateView(
      icon: Icons.event_busy_rounded,
      title: 'Tidak Ada Jadwal Presensi',
      message: 'Tidak ada sesi perkuliahan atau riwayat absensi yang tercatat pada tanggal yang dipilih.',
    );
  }
}

