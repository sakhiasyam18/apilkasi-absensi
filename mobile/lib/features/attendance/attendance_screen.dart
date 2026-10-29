import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/error_utils.dart';
import '../classes/data/classes_repository.dart';
import '../classes/models/class_model.dart';
import 'data/attendance_repository.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  final int? initialClassId;

  const AttendanceScreen({super.key, this.initialClassId});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _activityController = TextEditingController();

  ClassItem? _selectedClass;
  int _meetingNumber = 1;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _activityController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) {
    final year = d.year.toString().padLeft(4, '0');
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _formatTime(TimeOfDay t) {
    final hour = t.hour.toString().padLeft(2, '0');
    final minute = t.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _handleStartSession() async {
    if (_selectedClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih kelas terlebih dahulu.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedClass!.studentCount == 0) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Expanded(child: Text('Roster Kelas Kosong')),
            ],
          ),
          content: const Text(
            'Kelas ini belum memiliki mahasiswa di roster. Silakan tambahkan mahasiswa atau import CSV terlebih dahulu sebelum memulai sesi presensi (BR-03).',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.push('/classes/${_selectedClass!.id}');
              },
              child: const Text('Buka Roster Kelas'),
            ),
          ],
        ),
      );
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final repo = ref.read(attendanceRepositoryProvider);
      final session = await repo.createSession(
        classId: _selectedClass!.id,
        activityName: _activityController.text,
        sessionDate: _formatDate(_selectedDate),
        sessionTime: _formatTime(_selectedTime),
        meetingNumber: _meetingNumber,
      );

      if (!mounted) return;

      if (session.withoutFacesCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Perhatian: Ada ${session.withoutFacesCount} mahasiswa di kelas ini yang belum mendaftarkan wajah.',
            ),
            backgroundColor: Colors.orange.shade800,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      // Navigasikan user ke halaman sesi presensi
      context.push('/session/${session.id}', extra: session);
    } on DioException catch (e) {
      final msg = ErrorUtils.getErrorMessage(e, 'Gagal membuat sesi presensi');

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red),
                SizedBox(width: 8),
                Expanded(child: Text('Gagal Memulai Sesi')),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(classesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mulai Presensi Kelas'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: classesAsync.when(
        data: (classes) {
          if (classes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.school_outlined, size: 72, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text(
                      'Belum Ada Kelas Tersedia',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Harap buat kelas dan isi roster mahasiswa terlebih dahulu sebelum memulai presensi.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Kelola Kelas'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => context.push('/classes'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Auto-select initial class jika ada
          if (_selectedClass == null && classes.isNotEmpty) {
            if (widget.initialClassId != null) {
              _selectedClass = classes.firstWhere(
                (c) => c.id == widget.initialClassId,
                orElse: () => classes.first,
              );
            } else {
              _selectedClass = classes.first;
            }
            if (_activityController.text.isEmpty && _selectedClass != null) {
              _activityController.text = _selectedClass!.name;
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Card Header
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.indigo.shade100),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: Colors.indigo.shade50,
                            foregroundColor: Colors.indigo,
                            child: const Icon(Icons.camera_enhance, size: 28),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sesi Presensi Baru',
                                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Pilih kelas dan tentukan jadwal pertemuan untuk memotret kehadiran.',
                                  style: TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 1. Dropdown Pilih Kelas
                  const Text(
                    'Pilih Kelas *',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<ClassItem>(
                    initialValue: _selectedClass,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.school, color: Colors.indigo),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: classes.map((c) {
                      final hasCode = c.code != null && c.code!.isNotEmpty;
                      return DropdownMenuItem<ClassItem>(
                        value: c,
                        child: Text(
                          hasCode ? '${c.name} (${c.code})' : c.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedClass = val;
                          _activityController.text = val.name;
                        });
                      }
                    },
                  ),
                  if (_selectedClass != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedClass!.studentCount > 0 ? Colors.indigo.shade50 : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _selectedClass!.studentCount > 0 ? Icons.people_outline : Icons.warning_amber,
                            size: 16,
                            color: _selectedClass!.studentCount > 0 ? Colors.indigo : Colors.orange.shade800,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedClass!.studentCount > 0
                                  ? '${_selectedClass!.studentCount} Mahasiswa (${_selectedClass!.facesRegisteredCount} Terdaftar Wajah)'
                                  : 'Kelas belum memiliki mahasiswa di roster!',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _selectedClass!.studentCount > 0 ? Colors.indigo.shade900 : Colors.orange.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // 2. Nama Kegiatan / Mata Kuliah
                  const Text(
                    'Nama Kegiatan / Sesi *',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _activityController,
                    decoration: InputDecoration(
                      hintText: 'mis. Pemrograman Mobile A',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.edit_note, color: Colors.indigo),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Nama kegiatan tidak boleh kosong';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // 3. Pertemuan Ke-
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Pertemuan Ke-',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 18),
                              onPressed: _meetingNumber > 1
                                  ? () => setState(() => _meetingNumber--)
                                  : null,
                            ),
                            Text(
                              '$_meetingNumber',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 18),
                              onPressed: () => setState(() => _meetingNumber++),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 4. Tanggal & Jam
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Tanggal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: _pickDate,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 18, color: Colors.indigo),
                                    const SizedBox(width: 8),
                                    Text(_formatDate(_selectedDate), style: const TextStyle(fontWeight: FontWeight.w600)),
                                  ],
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
                            const Text('Waktu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: _pickTime,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 18, color: Colors.indigo),
                                    const SizedBox(width: 8),
                                    Text(_formatTime(_selectedTime), style: const TextStyle(fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Tombol Mulai Sesi Presensi
                  ElevatedButton.icon(
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow),
                    label: Text(
                      _isLoading ? 'Memulai Sesi...' : 'Mulai Sesi Presensi',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isLoading ? null : _handleStartSession,
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 12),
              Text('Gagal memuat data kelas: $err'),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
                onPressed: () => ref.invalidate(classesListProvider),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
