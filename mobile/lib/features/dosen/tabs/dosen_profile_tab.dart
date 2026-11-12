import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/luxury_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/presentation/auth_state.dart';

class DosenProfileTab extends ConsumerWidget {
  const DosenProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    final displayName = user?.fullName ?? 'Dr. Ir. Ashar Pakawaru, S.T., M.T.';
    final displayNip = user?.identifier ?? '19750815 200212 1 002';
    final displayEmail = user?.email ?? 'ashar.pakawaru@um.ac.id';
    final displayProdi = user?.programStudy ?? 'S1 Teknik Informatika - Universitas Negeri Malang';

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            children: [
              // Profile Header Card with Avatar
              _buildProfileHeaderCard(displayName, displayNip, displayProdi),
              const SizedBox(height: 20),

              // Face Data Status Banner
              _buildFaceStatusBanner(context),
              const SizedBox(height: 20),

              // Account Information Card
              _buildAccountInfoCard(displayEmail, displayNip, displayProdi),
              const SizedBox(height: 20),

              // Settings & Server Shortcut Card
              _buildSettingsCard(context),
              const SizedBox(height: 20),

              // Help & Support FAQ Accordion
              _buildFaqSection(),
              const SizedBox(height: 24),

              // Logout Button
              _buildLogoutButton(context, ref),
              const SizedBox(height: 18),
              const Center(
                child: Text(
                  'SnapAttend v3.2.5 • Universitas Negeri Malang (UM)',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeaderCard(String name, String nip, String prodi) {
    return LuxuryCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AppColors.cardSurfaceHover,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.school_rounded,
                    size: 46,
                    color: AppColors.primaryLight,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 14, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'NIP. $nip',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Dosen Pengampu Aktif • UM',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaceStatusBanner(BuildContext context) {
    return LuxuryCard(
      padding: const EdgeInsets.all(16),
      onTap: () => context.push('/register'),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.face_retouching_natural_rounded,
              color: AppColors.primaryLight,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Data Biometrik Wajah',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'InsightFace 512-dimensi aktif',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const StatusBadge(status: 'registered'),
        ],
      ),
    );
  }

  Widget _buildAccountInfoCard(String email, String nip, String prodi) {
    return LuxuryCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informasi Akun',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          _buildInfoRow(Icons.mail_outline_rounded, 'Email Kampus', email),
          const Divider(color: AppColors.border, height: 20),
          _buildInfoRow(Icons.badge_outlined, 'NIP Pegawai', nip),
          const Divider(color: AppColors.border, height: 20),
          _buildInfoRow(Icons.account_balance_outlined, 'Program Studi', prodi),
          const Divider(color: AppColors.border, height: 20),
          _buildInfoRow(Icons.security_outlined, 'Status Keamanan', 'Terautentikasi (Offline & Online)'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primaryLight),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsCard(BuildContext context) {
    return LuxuryCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pengaturan & Konfigurasi',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          _buildActionRow(
            icon: Icons.wifi_tethering_rounded,
            title: 'Konfigurasi IP Backend',
            subtitle: 'Ubah alamat IP server FastAPI InsightFace',
            onTap: () => context.push('/settings'),
          ),
          const Divider(color: AppColors.border, height: 20),
          _buildActionRow(
            icon: Icons.camera_enhance_outlined,
            title: 'Ambang Batas Pengenalan (Threshold)',
            subtitle: 'Default Cosine Distance 0.45 (Optimal UM)',
            onTap: () => context.push('/settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.cardSurfaceHover,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: AppColors.primaryLight),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
        ],
      ),
    );
  }

  Widget _buildFaqSection() {
    return LuxuryCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bantuan & Tanya Jawab (FAQ)',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          _buildFaqTile(
            'Bagaimana cara kerja presensi wajah SnapAttend?',
            'Aplikasi menggunakan kamera ponsel untuk mendeteksi wajah dengan Google ML Kit, lalu mengekstrak fitur 512-dimensi menggunakan model InsightFace (buffalo_l) di backend untuk mencocokkan mahasiswa secara instan.',
          ),
          const Divider(color: AppColors.border, height: 16),
          _buildFaqTile(
            'Bagaimana jika mahasiswa belum terdaftar wajahnya?',
            'Dosen dapat mendaftarkan wajah mahasiswa melalui menu "Daftar Wajah" dengan 5 pose (Lurus, Kiri, Kanan, Senyum, Dongak) atau mengubah status kehadiran secara manual di sesi.',
          ),
          const Divider(color: AppColors.border, height: 16),
          _buildFaqTile(
            'Bagaimana mengimpor daftar mahasiswa?',
            'Buka tab "Kelas", pilih kelas, lalu unggah file CSV berisi kolom NIM dan Nama Lengkap.',
          ),
        ],
      ),
    );
  }

  Widget _buildFaqTile(String question, String answer) {
    return Theme(
      data: ThemeData.dark().copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(
          question,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        iconColor: AppColors.primaryLight,
        collapsedIconColor: AppColors.textMuted,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              answer,
              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.alpa,
          side: const BorderSide(color: AppColors.alpa, width: 1.2),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: () async {
          await ref.read(authProvider.notifier).logout();
          if (context.mounted) {
            context.go('/login');
          }
        },
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: const Text(
          'Keluar dari Akun Dosen',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
