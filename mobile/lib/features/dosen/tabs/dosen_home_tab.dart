import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/luxury_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../auth/presentation/auth_state.dart';
import '../../classes/data/classes_repository.dart';
import '../../classes/models/class_model.dart';

class DosenHomeTab extends ConsumerWidget {
  final VoidCallback onNavigateToClasses;
  final VoidCallback onNavigateToHistory;

  const DosenHomeTab({
    super.key,
    required this.onNavigateToClasses,
    required this.onNavigateToHistory,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final classesAsync = ref.watch(classesListProvider);

    final displayName = user?.fullName ?? 'Dr. Ir. Ashar Pakawaru, S.T., M.T.';
    final displayRole = user?.isDosen ?? true
        ? 'Dosen Pengampu • Teknik Informatika'
        : 'Mahasiswa • Teknik Informatika';

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.cardSurface,
          onRefresh: () async {
            ref.invalidate(classesListProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header: Greeting, User Name, Avatar
                _buildHeader(context, displayName, displayRole),
                const SizedBox(height: 20),

                // Date & Academic Info Card
                _buildDateBanner(),
                const SizedBox(height: 20),

                // Statistics Summary Row
                classesAsync.when(
                  data: (classes) => _buildStatsRow(classes),
                  loading: () => _buildStatsLoading(),
                  error: (err, stack) => _buildStatsRow([]),
                ),
                const SizedBox(height: 24),

                // Quick Action Shortcuts Grid
                _buildQuickActions(context),
                const SizedBox(height: 28),

                // Header: Jadwal Kelas Hari Ini
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Jadwal Kelas Hari Ini',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: 0.2,
                      ),
                    ),
                    TextButton(
                      onPressed: onNavigateToClasses,
                      child: const Row(
                        children: [
                          Text(
                            'Semua Kelas',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryLight,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.primaryLight),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // List of Today's Classes or Empty State
                classesAsync.when(
                  data: (classes) {
                    if (classes.isEmpty) {
                      return LuxuryCard(
                        padding: const EdgeInsets.all(24),
                        child: EmptyStateView(
                          icon: Icons.menu_book_rounded,
                          title: 'Belum Ada Kelas Terdaftar',
                          message:
                              'Database saat ini bersih & kosong (0 kelas). Silakan tambahkan kelas baru untuk memulai penjadwalan dan presensi wajah.',
                          buttonText: 'Tambah Kelas Pertama',
                          buttonIcon: Icons.add_rounded,
                          onButtonPressed: onNavigateToClasses,
                        ),
                      );
                    }
                    return Column(
                      children: classes
                          .map((cls) => _buildClassCard(context, cls))
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
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Icon(Icons.cloud_off_rounded, color: AppColors.alpa, size: 36),
                        const SizedBox(height: 10),
                        const Text(
                          'Koneksi Backend Terputus',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Pastikan server FastAPI berjalan di komputer Anda.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        PrimaryButton(
                          text: 'Pengaturan IP',
                          height: 40,
                          icon: Icons.settings,
                          onPressed: () => context.push('/settings'),
                        ),
                      ],
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

  Widget _buildHeader(BuildContext context, String name, String role) {
    return Row(
      children: [
        // Avatar with emerald border
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.cardSurfaceHover,
            border: Border.all(color: AppColors.primary, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.2),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.person_rounded,
              size: 32,
              color: AppColors.primaryLight,
            ),
          ),
        ),
        const SizedBox(width: 14),

        // Greeting and Name
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Selamat Datang,',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      role,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Quick Settings Button
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary),
          tooltip: 'Pengaturan IP Server',
          onPressed: () => context.push('/settings'),
        ),
      ],
    );
  }

  Widget _buildDateBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.bgNavy,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calendar_today_rounded,
              color: AppColors.primaryLight,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Semester Gasal 2026/2027',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Senin, 2 November 2026',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Aktif',
              style: TextStyle(
                color: AppColors.primaryLight,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(List<ClassItem> classes) {
    final totalClasses = classes.length;
    final totalStudents = classes.fold<int>(0, (sum, c) => sum + c.studentCount);
    final totalFaces = classes.fold<int>(0, (sum, c) => sum + c.facesRegisteredCount);

    return Row(
      children: [
        Expanded(
          child: _buildStatItem(
            title: 'Total Kelas',
            value: '$totalClasses',
            subtitle: 'Mata Kuliah',
            icon: Icons.class_outlined,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatItem(
            title: 'Mahasiswa',
            value: '$totalStudents',
            subtitle: 'Terdaftar',
            icon: Icons.groups_outlined,
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatItem(
            title: 'Wajah Siap',
            value: '$totalFaces',
            subtitle: 'Embeddings',
            icon: Icons.face_rounded,
            color: AppColors.accentPurple,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return LuxuryCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10.5,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsLoading() {
    return Row(
      children: [
        Expanded(child: _buildStatItem(title: 'Total Kelas', value: '-', subtitle: '...', icon: Icons.class_outlined, color: AppColors.primary)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatItem(title: 'Mahasiswa', value: '-', subtitle: '...', icon: Icons.groups_outlined, color: AppColors.secondary)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatItem(title: 'Wajah Siap', value: '-', subtitle: '...', icon: Icons.face_rounded, color: AppColors.accentPurple)),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildQuickActionButton(
            label: 'Ambil Presensi',
            icon: Icons.camera_alt_rounded,
            color: AppColors.primary,
            onTap: () => context.push('/attendance'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildQuickActionButton(
            label: 'Tambah Kelas',
            icon: Icons.add_circle_outline_rounded,
            color: AppColors.secondary,
            onTap: onNavigateToClasses,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildQuickActionButton(
            label: 'Daftar Wajah',
            icon: Icons.face_retouching_natural_rounded,
            color: AppColors.accentPurple,
            onTap: () => context.push('/register'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildQuickActionButton(
            label: 'Riwayat',
            icon: Icons.history_rounded,
            color: AppColors.izin,
            onTap: onNavigateToHistory,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return LuxuryCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassCard(BuildContext context, ClassItem cls) {
    final room = cls.room?.isNotEmpty == true ? cls.room! : 'Ruang G4-201';
    final time = cls.scheduleTime?.isNotEmpty == true ? cls.scheduleTime! : '07:30 - 09:10 WIB';

    return LuxuryCard(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: AppColors.primaryLight,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cls.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (cls.code != null && cls.code!.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.bgDark,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              cls.code!,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        const Icon(Icons.room_outlined, size: 13, color: AppColors.textMuted),
                        const SizedBox(width: 3),
                        Text(
                          room,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                time,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.cardSurfaceHover,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.people_outline_rounded, size: 13, color: AppColors.primaryLight),
                    const SizedBox(width: 4),
                    Text(
                      '${cls.studentCount} Mahasiswa',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Primary Action: Ambil Presensi
          PrimaryButton(
            text: 'Ambil Presensi Sekarang',
            icon: Icons.camera_alt_rounded,
            onPressed: () {
              context.push('/attendance?class_id=${cls.id}');
            },
          ),
        ],
      ),
    );
  }
}
