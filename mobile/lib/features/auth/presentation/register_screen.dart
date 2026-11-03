import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/luxury_card.dart';
import '../../../core/widgets/primary_button.dart';
import 'auth_state.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  int _currentStep = 0;
  String _selectedRole = 'dosen'; // 'dosen' or 'mahasiswa'

  final _nameController = TextEditingController();
  final _identifierController = TextEditingController(); // NIP or NIM
  final _prodiController = TextEditingController(text: 'S1 Teknik Informatika');
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _identifierController.dispose();
    _prodiController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleRegister() async {
    final name = _nameController.text.trim();
    final identifier = _identifierController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Semua kolom wajib diisi'),
          backgroundColor: AppColors.alpa,
        ),
      );
      return;
    }

    final success = await ref.read(authProvider.notifier).register(
      email: email,
      password: password,
      fullName: name,
      identifier: identifier.isNotEmpty ? identifier : null,
      role: _selectedRole,
      programStudy: _prodiController.text.trim(),
    );

    if (success && mounted) {
      setState(() {
        _currentStep = 2; // Move to Face Capture prompt
      });
    } else if (mounted) {
      final msg = ref.read(authProvider).errorMessage ?? 'Registrasi gagal';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.alpa),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: const Text('Pendaftaran Akun'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () {
            if (_currentStep > 0 && _currentStep < 2) {
              setState(() => _currentStep--);
            } else {
              context.pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step indicator
              _buildStepIndicator(),
              const SizedBox(height: 24),

              if (_currentStep == 0) _buildRoleSelectionStep(),
              if (_currentStep == 1) _buildFormStep(authState.isLoading),
              if (_currentStep == 2) _buildFaceRegistrationStep(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      children: [
        _buildStepBadge(0, 'Peran'),
        _buildStepDivider(0),
        _buildStepBadge(1, 'Profil'),
        _buildStepDivider(1),
        _buildStepBadge(2, 'Wajah'),
      ],
    );
  }

  Widget _buildStepBadge(int stepIndex, String title) {
    final isActive = _currentStep == stepIndex;
    final isDone = _currentStep > stepIndex;

    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isDone
                ? AppColors.primary
                : (isActive ? AppColors.primary.withValues(alpha: 0.2) : AppColors.cardSurface),
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive || isDone ? AppColors.primary : AppColors.border,
              width: 1.5,
            ),
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text(
                    '${stepIndex + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isActive ? AppColors.primaryLight : AppColors.textMuted,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? AppColors.textPrimary : AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildStepDivider(int afterStep) {
    final isDone = _currentStep > afterStep;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        color: isDone ? AppColors.primary : AppColors.border,
      ),
    );
  }

  // STEP 0: Pilih Peran (Figma Page 2)
  Widget _buildRoleSelectionStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pilih Peran Anda',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        const SizedBox(height: 6),
        const Text(
          'Tentukan peran Anda dalam sistem presensi SnapAttend',
          style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 28),

        // Role Card: Dosen
        _buildRoleCard(
          role: 'dosen',
          title: 'Dosen Pengampu',
          subtitle: 'Kelola kelas, ambil presensi di ruang kuliah, dan pantau rekapitulasi kehadiran mahasiswa',
          icon: Icons.school_rounded,
        ),
        const SizedBox(height: 16),

        // Role Card: Mahasiswa
        _buildRoleCard(
          role: 'mahasiswa',
          title: 'Mahasiswa',
          subtitle: 'Lihat status kehadiran pribadi, riwayat presensi kelas, dan poin keaktifan kuliah',
          icon: Icons.person_rounded,
        ),
        const SizedBox(height: 36),

        PrimaryButton(
          text: 'Lanjutkan',
          icon: Icons.arrow_forward_rounded,
          onPressed: () {
            setState(() => _currentStep = 1);
          },
        ),
      ],
    );
  }

  Widget _buildRoleCard({
    required String role,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedRole == role;

    return LuxuryCard(
      onTap: () {
        setState(() => _selectedRole = role);
      },
      backgroundColor: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.cardSurface,
      border: Border.all(
        color: isSelected ? AppColors.primary : AppColors.border,
        width: isSelected ? 2 : 1,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withValues(alpha: 0.25) : AppColors.bgDark,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 26,
              color: isSelected ? AppColors.primaryLight : AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    if (isSelected)
                      const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // STEP 1: Formulir Data Diri
  Widget _buildFormStep(bool isLoading) {
    final isDosen = _selectedRole == 'dosen';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isDosen ? 'Data Profil Dosen' : 'Data Profil Mahasiswa',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        const SizedBox(height: 6),
        const Text(
          'Isi informasi lengkap untuk membuat akun baru Anda',
          style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),

        LuxuryCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nama Lengkap', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: isDosen ? 'Contoh: Dr. Ir. Ashar Pakawaru, S.T., M.T.' : 'Contoh: Budi Santoso',
                  prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.textMuted, size: 20),
                ),
              ),
              const SizedBox(height: 16),

              Text(isDosen ? 'NIP Dosen' : 'NIM Mahasiswa (12 Digit)', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _identifierController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: isDosen ? 'Contoh: 19750815 200212 1 002' : 'Contoh: 210535614401',
                  prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.textMuted, size: 20),
                ),
              ),
              const SizedBox(height: 16),

              const Text('Program Studi / Departemen', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _prodiController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'S1 Teknik Informatika - UM',
                  prefixIcon: Icon(Icons.account_balance_outlined, color: AppColors.textMuted, size: 20),
                ),
              ),
              const SizedBox(height: 16),

              const Text('Email', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'nama@um.ac.id',
                  prefixIcon: Icon(Icons.mail_outline_rounded, color: AppColors.textMuted, size: 20),
                ),
              ),
              const SizedBox(height: 16),

              const Text('Kata Sandi', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Minimal 6 karakter',
                  prefixIcon: Icon(Icons.lock_outline_rounded, color: AppColors.textMuted, size: 20),
                ),
              ),
              const SizedBox(height: 24),

              PrimaryButton(
                text: 'Simpan & Buat Akun',
                icon: Icons.check_rounded,
                isLoading: isLoading,
                onPressed: _handleRegister,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // STEP 2: Rekomendasi Registrasi Wajah
  Widget _buildFaceRegistrationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Akun Berhasil Dibuat!',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        const SizedBox(height: 6),
        const Text(
          'Daftarkan data biometrik wajah Anda sekarang agar sistem dapat mengenali Anda secara otomatis',
          style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 28),

        LuxuryCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primaryLight, width: 2),
                ),
                child: const Icon(Icons.face_retouching_natural_rounded, size: 40, color: AppColors.primaryLight),
              ),
              const SizedBox(height: 16),
              const Text(
                'Registrasi 5 Pose Wajah',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                'Perekaman 5 pose wajah (Lurus, Kiri, Kanan, Senyum, Dongak) menggunakan InsightFace 512-dimensi untuk akurasi tinggi tanpa tersesat',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 24),

              PrimaryButton(
                text: 'Mulai Perekaman Wajah',
                icon: Icons.camera_alt_rounded,
                onPressed: () {
                  context.push('/register');
                },
              ),
              const SizedBox(height: 12),

              PrimaryButton(
                text: 'Nanti Saja (Masuk Dashboard)',
                isOutlined: true,
                onPressed: () {
                  context.go('/');
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
