import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';

class StudentLookupData {
  final int id;
  final String nim;
  final String fullName;
  final bool hasFaces;
  final List<String> classNames;

  StudentLookupData({
    required this.id,
    required this.nim,
    required this.fullName,
    required this.hasFaces,
    required this.classNames,
  });

  factory StudentLookupData.fromJson(Map<String, dynamic> json) {
    final classesList = (json['classes'] as List<dynamic>? ?? [])
        .map((c) => (c['name'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toList();

    return StudentLookupData(
      id: json['id'] as int,
      nim: json['nim'] as String,
      fullName: json['full_name'] as String,
      hasFaces: json['has_faces'] is bool
          ? json['has_faces'] as bool
          : (json['has_faces'] == 1),
      classNames: classesList,
    );
  }
}

class LookupScreen extends ConsumerStatefulWidget {
  const LookupScreen({super.key});

  @override
  ConsumerState<LookupScreen> createState() => _LookupScreenState();
}

class _LookupScreenState extends ConsumerState<LookupScreen> {
  final _nimController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  String? _errorMessage;
  StudentLookupData? _studentData;

  @override
  void dispose() {
    _nimController.dispose();
    super.dispose();
  }

  Future<void> _handleLookup() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _studentData = null;
    });

    final nim = _nimController.text.trim();
    try {
      final dio = ref.read(apiClientProvider);
      final response = await dio.get(
        '/students/lookup',
        queryParameters: {'nim': nim},
      );

      setState(() {
        _studentData = StudentLookupData.fromJson(response.data as Map<String, dynamic>);
      });
    } on DioException catch (e) {
      String msg = 'Gagal melakukan verifikasi NIM';
      if (e.response?.statusCode == 404) {
        msg = 'NIM belum terdaftar di kelas manapun. Hubungi dosen.';
      } else if (e.response?.statusCode == 422) {
        msg = 'Format NIM tidak valid. Pastikan 12 digit angka.';
      } else {
        final errData = e.response?.data?['detail'];
        if (errData is Map && errData['message'] != null) {
          msg = errData['message'];
        } else if (errData is String) {
          msg = errData;
        } else if (e.message != null) {
          msg = e.message!;
        }
      }

      setState(() {
        _errorMessage = msg;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Terjadi kesalahan: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _proceedToCapture(StudentLookupData student) {
    if (student.hasFaces) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Expanded(child: Text('Konfirmasi Daftar Ulang')),
            ],
          ),
          content: const Text(
            'Wajah Anda sudah terdaftar di sistem. Mendaftar ulang akan menimpa data wajah sebelumnya.\n\n'
            'Pendaftaran ulang memerlukan izin dan pendampingan dari dosen (BR-14).\n\n'
            'Apakah Anda yakin ingin melanjutkan?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade800,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                context.push(
                  '/register/capture',
                  extra: {
                    'student_id': student.id,
                    'student_name': student.fullName,
                    'nim': student.nim,
                    'overwrite': true,
                  },
                );
              },
              child: const Text('Ya, Daftar Ulang'),
            ),
          ],
        ),
      );
    } else {
      context.push(
        '/register/capture',
        extra: {
          'student_id': student.id,
          'student_name': student.fullName,
          'nim': student.nim,
          'overwrite': false,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrasi Wajah'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.face_retouching_natural, size: 72, color: Colors.indigo),
            const SizedBox(height: 12),
            const Text(
              'Verifikasi Identitas Mahasiswa',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Masukkan NIM yang telah didaftarkan dosen ke dalam roster kelas.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 24),

            // Form Input NIM
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _nimController,
                keyboardType: TextInputType.number,
                maxLength: 12,
                decoration: InputDecoration(
                  labelText: 'Nomor Induk Mahasiswa (NIM)',
                  hintText: 'mis. 240535600363',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  counterText: '',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'NIM wajib diisi';
                  }
                  if (!RegExp(r'^\d{12}$').hasMatch(val.trim())) {
                    return 'NIM harus tepat 12 digit angka (BR-01)';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              label: Text(_isLoading ? 'Memeriksa...' : 'Cari Data Mahasiswa'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isLoading ? null : _handleLookup,
            ),
            const SizedBox(height: 20),

            // Pesan Error jika tidak ditemukan
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade900, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            // Kartu Data Mahasiswa jika ditemukan
            if (_studentData != null) ...[
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: Colors.indigo.shade50,
                            foregroundColor: Colors.indigo,
                            child: const Icon(Icons.person, size: 30),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _studentData!.fullName,
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'NIM: ${_studentData!.nim}',
                                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          const Icon(Icons.class_outlined, size: 18, color: Colors.indigo),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _studentData!.classNames.isNotEmpty
                                  ? 'Kelas: ${_studentData!.classNames.join(', ')}'
                                  : 'Kelas: Belum terdaftar di kelas manapun',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            _studentData!.hasFaces ? Icons.check_circle : Icons.warning_amber,
                            size: 18,
                            color: _studentData!.hasFaces ? Colors.green : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _studentData!.hasFaces
                                ? 'Status: Wajah sudah pernah terdaftar'
                                : 'Status: Belum mendaftarkan wajah',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _studentData!.hasFaces ? Colors.green.shade800 : Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Ya, ini saya (Lanjut ke Foto)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _proceedToCapture(_studentData!),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
