import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/error_utils.dart';
import 'data/attendance_repository.dart';
import 'models/session_model.dart';

class AttendanceResultScreen extends ConsumerStatefulWidget {
  final int sessionId;
  final RecognizeResult initialResult;
  final String imagePath;

  const AttendanceResultScreen({
    super.key,
    required this.sessionId,
    required this.initialResult,
    required this.imagePath,
  });

  @override
  ConsumerState<AttendanceResultScreen> createState() =>
      _AttendanceResultScreenState();
}

class _AttendanceResultScreenState
    extends ConsumerState<AttendanceResultScreen> {
  late RecognizeResult _result;
  late List<FaceBoxResult> _faces;
  late SessionProgressData _progress;
  FaceBoxResult? _selectedFace;
  bool _isFinalizing = false;

  @override
  void initState() {
    super.initState();
    _result = widget.initialResult;
    _faces = List.from(widget.initialResult.faces);
    _progress = widget.initialResult.progress;
  }

  void _onImageTapped(TapUpDetails details, Size viewSize, Size imgSize) {
    FaceBoxResult? clickedFace;

    // Cari wajah unknown yang diketuk (Section 9.6)
    for (final face in _faces) {
      final screenRect = _toScreen(
        face.bbox.toRect(),
        imgSize,
        viewSize,
      );

      // Berikan toleransi sentuhan sedikit lebih besar
      if (screenRect.inflate(14).contains(details.localPosition)) {
        clickedFace = face;
        break;
      }
    }

    if (clickedFace != null) {
      setState(() {
        _selectedFace = clickedFace;
      });

      if (clickedFace.status == 'unknown') {
        _showManualVerificationSheet(clickedFace);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              clickedFace.fullName != null
                  ? '${clickedFace.fullName} (${clickedFace.status == "identified" ? "Dikenali AI" : "Dikonfirmasi"})'
                  : 'Wajah Terdeteksi',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Rect _toScreen(Rect b, Size img, Size view) {
    final scale = min(view.width / img.width, view.height / img.height);
    final dx = (view.width - img.width * scale) / 2;
    final dy = (view.height - img.height * scale) / 2;
    return Rect.fromLTWH(
      b.left * scale + dx,
      b.top * scale + dy,
      b.width * scale,
      b.height * scale,
    );
  }

  void _showManualVerificationSheet(FaceBoxResult targetFace) {
    final unidentList = _progress.unidentified;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = unidentList.where((u) {
              return u.fullName.toLowerCase().contains(searchQuery.toLowerCase()) ||
                  u.nim.contains(searchQuery);
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.65,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Row(
                        children: [
                          Icon(Icons.how_to_reg, color: Colors.indigo),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Konfirmasi Kehadiran Manual',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pilih mahasiswa yang sesuai dengan wajah ini (BR-07, BR-08):',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Cari nama atau NIM...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onChanged: (val) {
                          setModalState(() {
                            searchQuery = val;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      if (filtered.isEmpty)
                        Expanded(
                          child: Center(
                            child: Text(
                              unidentList.isEmpty
                                  ? 'Semua peserta sudah hadir!'
                                  : 'Mahasiswa tidak ditemukan',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.builder(
                            controller: scrollController,
                            itemCount: filtered.length,
                            itemBuilder: (context, idx) {
                              final st = filtered[idx];
                              return Card(
                                elevation: 0.5,
                                margin: const EdgeInsets.only(bottom: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                child: ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    backgroundColor: st.hasFaces
                                        ? Colors.blue.shade50
                                        : Colors.orange.shade50,
                                    foregroundColor: st.hasFaces
                                        ? Colors.blue.shade700
                                        : Colors.orange.shade800,
                                    child: const Icon(Icons.person, size: 18),
                                  ),
                                  title: Text(
                                    st.fullName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  subtitle: Row(
                                    children: [
                                      Text(
                                        'NIM: ${st.nim}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (!st.hasFaces)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade100,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'Tanpa Foto',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: Colors.orange.shade900,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  trailing: const Icon(
                                    Icons.check_circle_outline,
                                    color: Colors.indigo,
                                  ),
                                  onTap: () {
                                    Navigator.of(ctx).pop();
                                    _executeConfirmAttendance(targetFace, st);
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _executeConfirmAttendance(
    FaceBoxResult targetFace,
    UnidentifiedParticipant student,
  ) async {
    try {
      final repo = ref.read(attendanceRepositoryProvider);
      final updatedProgress = await repo.confirmAttendance(
        sessionId: widget.sessionId,
        studentId: student.studentId,
        faceId: targetFace.faceId,
      );

      setState(() {
        // Update status kotak wajah menjadi confirmed (Biru)
        targetFace.status = 'confirmed';
        targetFace.studentId = student.studentId;
        targetFace.fullName = student.fullName;
        targetFace.nim = student.nim;

        _progress = updatedProgress;
      });

      ref.invalidate(sessionDetailProvider(widget.sessionId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${student.fullName} berhasil dikonfirmasi hadir!'),
            backgroundColor: Colors.blue.shade700,
          ),
        );
      }
    } on DioException catch (e) {
      final msg = ErrorUtils.getErrorMessage(e, 'Gagal mengonfirmasi kehadiran');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showFinalizeConfirmationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_clock, color: Colors.indigo),
            SizedBox(width: 8),
            Expanded(child: Text('Selesaikan Presensi?')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Menyelesaikan sesi akan mengunci kehadiran mahasiswa dan mencatat poin resmi.',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Perkiraan Poin Mahasiswa:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  SizedBox(height: 4),
                  Text('• Hadir: +10 Poin', style: TextStyle(color: Colors.green, fontSize: 12)),
                  Text('• Tidak Hadir: -10 Poin', style: TextStyle(color: Colors.red, fontSize: 12)),
                  SizedBox(height: 4),
                  Text(
                    '(Poin resmi dihitung dan disimpan permanen di server)',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
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
            onPressed: () {
              Navigator.of(ctx).pop();
              _executeFinalizeSession();
            },
            child: const Text('Selesaikan & Kunci'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeFinalizeSession() async {
    setState(() {
      _isFinalizing = true;
    });

    try {
      final repo = ref.read(attendanceRepositoryProvider);
      final finalResult = await repo.finalizeSession(widget.sessionId);

      ref.invalidate(sessionDetailProvider(widget.sessionId));
      ref.invalidate(classPointsProvider(finalResult.classId));

      if (!mounted) return;

      _showFinalSummaryDialog(finalResult);
    } on DioException catch (e) {
      final msg = ErrorUtils.getErrorMessage(e, 'Gagal menyelesaikan sesi');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFinalizing = false;
        });
      }
    }
  }

  void _showFinalSummaryDialog(FinalizeResult finalResult) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Expanded(child: Text('Presensi Berhasil Difinalisasi')),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sesi resmi ditutup. Poin mahasiswa kelas telah diperbarui.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const Divider(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: finalResult.results.length,
                  itemBuilder: (context, idx) {
                    final r = finalResult.results[idx];
                    final isHadir = r.status == 'hadir';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.fullName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'NIM: ${r.nim} • ${isHadir ? "Hadir" : "Tidak Hadir"}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isHadir ? Colors.green.shade700 : Colors.red.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${r.delta > 0 ? "+" : ""}${r.delta}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: r.delta > 0 ? Colors.green : Colors.red,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                'Total: ${r.classTotalPoints} pt',
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go('/session/${widget.sessionId}');
            },
            child: const Text('Kembali ke Detail Sesi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageFile = File(widget.imagePath);
    final total = _progress.totalParticipants;
    final identifiedCount = _progress.identified.length;
    final progressFraction = total > 0 ? (identifiedCount / total).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Hasil Jepretan ${_result.captureNo}/${_result.maxCaptures}'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          if (_result.captureNo < _result.maxCaptures)
            IconButton(
              icon: const Icon(Icons.add_a_photo),
              tooltip: 'Foto Sudut Lain',
              onPressed: () {
                context.pushReplacement('/session/${widget.sessionId}/capture');
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // 1. Gambar & Bounding Box Overlay
          Expanded(
            flex: 6,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final viewSize = Size(constraints.maxWidth, constraints.maxHeight);
                final imgSize = Size(
                  _result.imageWidth.toDouble(),
                  _result.imageHeight.toDouble(),
                );

                return GestureDetector(
                  onTapUp: (details) => _onImageTapped(details, viewSize, imgSize),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Gambar asli hasil kompresi
                      Center(
                        child: imageFile.existsSync()
                            ? Image.file(
                                imageFile,
                                width: constraints.maxWidth,
                                height: constraints.maxHeight,
                                fit: BoxFit.contain,
                              )
                            : const Center(
                                child: Text('Gambar tidak ditemukan', style: TextStyle(color: Colors.white)),
                              ),
                      ),

                      // CustomPainter Bounding Boxes
                      CustomPaint(
                        size: viewSize,
                        painter: _BoundingBoxPainter(
                          faces: _faces,
                          imgSize: imgSize,
                          selectedFace: _selectedFace,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // 2. Bar Progres Kehadiran & Detail
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.people, size: 18, color: Colors.indigo),
                        const SizedBox(width: 6),
                        Text(
                          'Kehadiran: $identifiedCount / $total Mahasiswa',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    Text(
                      '${(progressFraction * 100).toInt()}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressFraction,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progressFraction >= 1.0 ? Colors.green : Colors.indigo,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Legend Kotak
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildLegendItem(Colors.green, 'AI Hadir'),
                    _buildLegendItem(Colors.blue, 'Konfirmasi'),
                    _buildLegendItem(Colors.redAccent, 'Belum (Ketuk)'),
                  ],
                ),
              ],
            ),
          ),

          // 3. Tombol Aksi Bawah
          SafeArea(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  if (_result.captureNo < _result.maxCaptures) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Sudut Lain'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.indigo,
                          side: const BorderSide(color: Colors.indigo),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          context.pushReplacement('/session/${widget.sessionId}/capture');
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      icon: _isFinalizing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: Text(_isFinalizing ? 'Menyimpan...' : 'Selesaikan Presensi'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _isFinalizing ? null : _showFinalizeConfirmationDialog,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black87)),
      ],
    );
  }
}

class _BoundingBoxPainter extends CustomPainter {
  final List<FaceBoxResult> faces;
  final Size imgSize;
  final FaceBoxResult? selectedFace;

  _BoundingBoxPainter({
    required this.faces,
    required this.imgSize,
    this.selectedFace,
  });

  Rect _toScreen(Rect b, Size img, Size view) {
    final scale = min(view.width / img.width, view.height / img.height);
    final dx = (view.width - img.width * scale) / 2;
    final dy = (view.height - img.height * scale) / 2;
    return Rect.fromLTWH(
      b.left * scale + dx,
      b.top * scale + dy,
      b.width * scale,
      b.height * scale,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final face in faces) {
      final screenRect = _toScreen(face.bbox.toRect(), imgSize, size);

      Color boxColor;
      if (face.status == 'identified') {
        boxColor = const Color(0xFF4CAF50); // Hijau
      } else if (face.status == 'confirmed') {
        boxColor = const Color(0xFF2196F3); // Biru
      } else {
        boxColor = const Color(0xFFFF5252); // Merah Accent (Unknown)
      }

      final isSelected = selectedFace?.faceId == face.faceId;

      final paint = Paint()
        ..color = boxColor
        ..strokeWidth = isSelected ? 3.5 : 2.0
        ..style = PaintingStyle.stroke;

      // Gambar kotak wajah
      canvas.drawRRect(
        RRect.fromRectAndRadius(screenRect, const Radius.circular(6)),
        paint,
      );

      // Label teks nama di atas kotak
      final labelText = face.status == 'identified'
          ? (face.fullName != null
              ? '${face.fullName!} (${((face.score ?? 0) * 100).toInt()}%)'
              : 'Hadir')
          : (face.status == 'confirmed'
              ? '${face.fullName ?? "Manual"} (✓)'
              : 'Tidak Dikenal (Ketuk)');

      final textSpan = TextSpan(
        text: labelText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final tagRect = Rect.fromLTWH(
        screenRect.left,
        max(0, screenRect.top - 18),
        textPainter.width + 8,
        16,
      );

      final bgPaint = Paint()..color = boxColor.withValues(alpha: 0.85);
      canvas.drawRRect(
        RRect.fromRectAndRadius(tagRect, const Radius.circular(4)),
        bgPaint,
      );

      textPainter.paint(
        canvas,
        Offset(tagRect.left + 4, tagRect.top + 1),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BoundingBoxPainter oldDelegate) => true;
}
