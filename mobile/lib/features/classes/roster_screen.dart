import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/classes_repository.dart';
import 'models/class_model.dart';

class RosterScreen extends ConsumerWidget {
  final int classId;

  const RosterScreen({super.key, required this.classId});

  Future<void> _handleCsvImport(BuildContext context, WidgetRef ref) async {
    try {
      final pickedFiles = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (pickedFiles.isEmpty) {
        return;
      }

      final pickedFile = pickedFiles.first;
      final fileBytes = await pickedFile.readAsBytes();

      if (fileBytes.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File CSV kosong atau tidak dapat dibaca.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (!context.mounted) return;

      // Tampilkan indikator loading saat upload CSV
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Expanded(child: Text('Memproses data CSV...')),
              ],
            ),
          ),
        ),
      );

      final repo = ref.read(classesRepositoryProvider);
      final result = await repo.importCsv(
        classId: classId,
        bytes: fileBytes,
        filename: pickedFile.name,
      );

      // Tutup dialog loading
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

      // Refresh data kelas dan roster
      ref.invalidate(classDetailProvider(classId));
      ref.invalidate(classesListProvider);

      if (context.mounted) {
        _showImportSummaryDialog(context, result);
      }
    } on DioException catch (e) {
      if (context.mounted) {
        // Pastikan loading dialog ditutup jika masih terbuka
        Navigator.of(context, rootNavigator: true).maybePop();

        final errData = e.response?.data?['detail'];
        final msg = errData is Map
            ? (errData['message'] ?? errData['code'] ?? e.message)
            : (errData ?? e.message ?? 'Gagal mengimpor CSV');

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red),
                SizedBox(width: 8),
                Text('Gagal Import CSV'),
              ],
            ),
            content: Text(msg.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).maybePop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showImportSummaryDialog(BuildContext context, RosterImportResult result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Ringkasan Import Roster'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSummaryRow(Icons.person_add, Colors.blue, 'Mahasiswa Baru Ditambahkan: ${result.added}'),
              const SizedBox(height: 6),
              _buildSummaryRow(Icons.link, Colors.indigo, 'Mahasiswa Terhubung: ${result.linkedExisting}'),
              const SizedBox(height: 6),
              _buildSummaryRow(Icons.skip_next, Colors.grey, 'Dilewati (Sudah Ada di Kelas): ${result.skipped}'),
              if (result.warnings.isNotEmpty) ...[
                const Divider(height: 20),
                Row(
                  children: [
                    const Icon(Icons.warning_amber, size: 18, color: Colors.orange),
                    const SizedBox(width: 6),
                    Text(
                      'Peringatan (${result.warnings.length}):',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ...result.warnings.map(
                  (w) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• Baris ${w['row']} (NIM ${w['nim']}): Nama di database "${w['existing_name']}" dipertahankan (BR-15).',
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ),
                ),
              ],
              if (result.errors.isNotEmpty) ...[
                const Divider(height: 20),
                Row(
                  children: [
                    const Icon(Icons.error_outline, size: 18, color: Colors.red),
                    const SizedBox(width: 6),
                    Text(
                      'Error (${result.errors.length}):',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ...result.errors.map(
                  (er) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• Baris ${er['row']} (NIM ${er['nim']}): ${er['code'] == 'validation_error' ? 'Format NIM/Nama tidak valid' : er['code']}',
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, Color color, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
      ],
    );
  }

  void _showAddManualDialog(BuildContext context, WidgetRef ref) {
    final nimController = TextEditingController();
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_add_alt_1, color: Colors.indigo),
            SizedBox(width: 8),
            Text('Tambah Mahasiswa'),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nimController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'NIM (12 Digit) *',
                  hintText: 'mis. 240535600363',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'NIM wajib diisi';
                  }
                  if (!RegExp(r'^\d{12}$').hasMatch(val.trim())) {
                    return 'NIM harus tepat 12 digit angka';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Lengkap *',
                  hintText: 'mis. Asyam Sakhi Maulana',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Nama tidak boleh kosong';
                  }
                  return null;
                },
              ),
            ],
          ),
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
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(ctx).pop();
                try {
                  final repo = ref.read(classesRepositoryProvider);
                  final result = await repo.addStudents(
                    classId,
                    [
                      {
                        'nim': nimController.text.trim(),
                        'full_name': nameController.text.trim(),
                      }
                    ],
                  );

                  ref.invalidate(classDetailProvider(classId));
                  ref.invalidate(classesListProvider);

                  if (context.mounted) {
                    _showImportSummaryDialog(context, result);
                  }
                } on DioException catch (e) {
                  final errData = e.response?.data?['detail'];
                  final msg = errData is Map
                      ? (errData['message'] ?? errData['code'] ?? e.message)
                      : (errData ?? e.message ?? 'Gagal menambahkan mahasiswa');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $msg'), backgroundColor: Colors.red),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Terjadi kesalahan: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(classDetailProvider(classId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Roster Kelas'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(classDetailProvider(classId));
          await ref.read(classDetailProvider(classId).future);
        },
        child: detailAsync.when(
          data: (classDetail) {
            final registeredCount = classDetail.students.where((s) => s.hasFaces).length;

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card Info Kelas
                        Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.indigo.shade100),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        classDetail.name,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (classDetail.code != null && classDetail.code!.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.indigo.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          classDetail.code!,
                                          style: TextStyle(
                                            color: Colors.indigo.shade800,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Chip(
                                      avatar: const Icon(Icons.people, size: 16, color: Colors.indigo),
                                      label: Text('${classDetail.students.length} / 15 Mahasiswa'),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    const SizedBox(width: 8),
                                    Chip(
                                      avatar: const Icon(Icons.face, size: 16, color: Colors.green),
                                      label: Text('$registeredCount Wajah Terdaftar'),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Action Buttons: Import CSV & Tambah Manual
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.upload_file),
                                label: const Text('Import CSV'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () => _handleCsvImport(context, ref),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.person_add),
                                label: const Text('Input Manual'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.indigo,
                                  side: const BorderSide(color: Colors.indigo),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () => _showAddManualDialog(context, ref),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Daftar Mahasiswa (${classDetail.students.length})',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            if (classDetail.students.length >= 15)
                              const Text(
                                'Kelas Penuh (Maks. 15)',
                                style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                          ],
                        ),
                        const Divider(),
                      ],
                    ),
                  ),
                ),
                if (classDetail.students.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_off_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text(
                            'Roster Masih Kosong',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Klik "Import CSV" atau "Input Manual" untuk mengisi roster.',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final student = classDetail.students[index];
                          return _StudentTile(student: student, index: index + 1);
                        },
                        childCount: classDetail.students.length,
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 32),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    const Text(
                      'Gagal Memuat Roster Kelas',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      err.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Coba Lagi'),
                      onPressed: () => ref.invalidate(classDetailProvider(classId)),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StudentTile extends StatelessWidget {
  final StudentItem student;
  final int index;

  const _StudentTile({required this.student, required this.index});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: student.hasFaces ? Colors.green.shade50 : Colors.grey.shade100,
          foregroundColor: student.hasFaces ? Colors.green.shade700 : Colors.grey.shade600,
          child: Text('$index', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        title: Text(
          student.fullName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          'NIM: ${student.nim}',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
        ),
        trailing: _buildFaceStatusBadge(student.hasFaces),
      ),
    );
  }

  Widget _buildFaceStatusBadge(bool hasFaces) {
    if (hasFaces) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          border: Border.all(color: Colors.green.shade300),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 14, color: Colors.green.shade700),
            const SizedBox(width: 4),
            Text(
              'Wajah Terdaftar',
              style: TextStyle(
                color: Colors.green.shade800,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          border: Border.all(color: Colors.orange.shade300),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cancel_outlined, size: 14, color: Colors.orange.shade700),
            const SizedBox(width: 4),
            Text(
              'Belum Terdaftar',
              style: TextStyle(
                color: Colors.orange.shade800,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
  }
}
