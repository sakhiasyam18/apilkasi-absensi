import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/luxury_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../classes/data/classes_repository.dart';
import '../../classes/models/class_model.dart';

class DosenClassesTab extends ConsumerStatefulWidget {
  const DosenClassesTab({super.key});

  @override
  ConsumerState<DosenClassesTab> createState() => _DosenClassesTabState();
}

class _DosenClassesTabState extends ConsumerState<DosenClassesTab> {
  String _selectedDay = 'Semua';
  final List<String> _days = ['Semua', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat'];
  String _searchQuery = '';

  void _showAddClassModal() {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final roomController = TextEditingController(text: 'Ruang G4-201');
    final timeController = TextEditingController(text: '07:30 - 09:10 WIB');
    String chosenDay = 'Senin';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgNavy,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Tambah Kelas Baru',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.textSecondary),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Masukkan data mata kuliah dan jadwal perkuliahan',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 20),

                    // Nama Kelas
                    const Text('Nama Mata Kuliah', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Contoh: Pemrograman Visual',
                        prefixIcon: Icon(Icons.book_outlined, color: AppColors.textMuted, size: 20),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Kode Kelas & Ruangan
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Kode Kelas', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: codeController,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                decoration: const InputDecoration(
                                  hintText: 'TIF-101',
                                  prefixIcon: Icon(Icons.tag, color: AppColors.textMuted, size: 20),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Ruangan', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: roomController,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                decoration: const InputDecoration(
                                  hintText: 'G4-201',
                                  prefixIcon: Icon(Icons.room_outlined, color: AppColors.textMuted, size: 20),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Hari & Jam
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Hari', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                decoration: BoxDecoration(
                                  color: AppColors.cardSurface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.border, width: 1),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: chosenDay,
                                    dropdownColor: AppColors.cardSurface,
                                    isExpanded: true,
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                    items: ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat']
                                        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                                        .toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setModalState(() => chosenDay = val);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Jam Kuliah', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: timeController,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                decoration: const InputDecoration(
                                  hintText: '07:30 - 09:10',
                                  prefixIcon: Icon(Icons.access_time, color: AppColors.textMuted, size: 20),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    PrimaryButton(
                      text: 'Simpan Kelas',
                      icon: Icons.check_rounded,
                      onPressed: () async {
                        final name = nameController.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Nama kelas tidak boleh kosong'),
                              backgroundColor: AppColors.alpa,
                            ),
                          );
                          return;
                        }

                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.of(ctx).pop();
                        try {
                          final repo = ref.read(classesRepositoryProvider);
                          await repo.createClass(
                            name: name,
                            code: codeController.text.trim(),
                            room: roomController.text.trim(),
                            scheduleDay: chosenDay,
                            scheduleTime: timeController.text.trim(),
                          );
                          ref.invalidate(classesListProvider);
                          if (mounted) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Kelas berhasil ditambahkan!'),
                                backgroundColor: AppColors.primary,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Gagal menambah kelas: $e'),
                                backgroundColor: AppColors.alpa,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(classesListProvider);

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
                // Top Header Row with Title and [ + Tambah Kelas ] Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manajemen Kelas',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Kelola mata kuliah & roster mahasiswa',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _showAddClassModal,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Tambah', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Search Bar
                TextField(
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Cari mata kuliah atau kode...',
                    prefixIcon: Icon(Icons.search_rounded, color: AppColors.textMuted),
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val.toLowerCase());
                  },
                ),
                const SizedBox(height: 16),

                // Day Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: _days.map((day) {
                      final isSelected = _selectedDay == day;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(day),
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
                            setState(() => _selectedDay = day);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 18),

                // Classes List or Zero-State
                classesAsync.when(
                  data: (classes) {
                    var filtered = classes;
                    if (_selectedDay != 'Semua') {
                      filtered = filtered
                          .where((c) => (c.scheduleDay ?? '').toLowerCase() == _selectedDay.toLowerCase())
                          .toList();
                    }
                    if (_searchQuery.isNotEmpty) {
                      filtered = filtered.where((c) {
                        final nameMatch = c.name.toLowerCase().contains(_searchQuery);
                        final codeMatch = (c.code ?? '').toLowerCase().contains(_searchQuery);
                        return nameMatch || codeMatch;
                      }).toList();
                    }

                    if (filtered.isEmpty) {
                      return LuxuryCard(
                        padding: const EdgeInsets.all(28),
                        child: EmptyStateView(
                          icon: Icons.menu_book_rounded,
                          title: 'Belum Ada Kelas',
                          message:
                              'Tidak ada data kelas yang sesuai filter. Data database saat ini bersih & kosong (0 kelas).',
                          buttonText: 'Tambah Kelas Baru',
                          buttonIcon: Icons.add_rounded,
                          onButtonPressed: _showAddClassModal,
                        ),
                      );
                    }

                    return Column(
                      children: filtered
                          .map((cls) => _buildClassManageCard(context, cls))
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
                    child: Center(
                      child: Text('Gagal memuat kelas: $err', style: const TextStyle(color: AppColors.alpa)),
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

  Widget _buildClassManageCard(BuildContext context, ClassItem cls) {
    final room = cls.room?.isNotEmpty == true ? cls.room! : 'Ruang G4-201';
    final day = cls.scheduleDay?.isNotEmpty == true ? cls.scheduleDay! : 'Senin';
    final time = cls.scheduleTime?.isNotEmpty == true ? cls.scheduleTime! : '07:30 - 09:10 WIB';

    return LuxuryCard(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.school_rounded, color: AppColors.primaryLight, size: 24),
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
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        const Icon(Icons.room_outlined, size: 13, color: AppColors.textMuted),
                        const SizedBox(width: 3),
                        Text(room, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 12),

          // Schedule & Counts
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text('$day, $time', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.cardSurfaceHover,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${cls.studentCount} Mhs (${cls.facesRegisteredCount} Wajah)',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Action Buttons: [ 👥 Mahasiswa ] | [ 🏆 Poin ] | [ 📷 Presensi ]
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => context.push('/classes/${cls.id}'),
                  icon: const Icon(Icons.people_outline_rounded, size: 16, color: AppColors.primaryLight),
                  label: const Text('Roster', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => context.push('/classes/${cls.id}/points'),
                  icon: const Icon(Icons.star_outline_rounded, size: 16, color: AppColors.izin),
                  label: const Text('Poin', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => context.push('/attendance?class_id=${cls.id}'),
                  icon: const Icon(Icons.camera_alt_rounded, size: 16),
                  label: const Text('Presensi', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
