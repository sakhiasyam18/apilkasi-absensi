import 'dart:async';
import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path/path.dart' as p;

import '../../core/api/api_client.dart';
import '../../core/utils/error_utils.dart';
import '../../core/utils/image_prep.dart';
import '../../core/utils/image_quality.dart';
import '../../services/upload_queue/queue_worker.dart';

class PoseTarget {
  final String label;
  final String title;
  final String instruction;
  final IconData icon;
  final bool Function(double yaw, double pitch) isMatch;

  const PoseTarget({
    required this.label,
    required this.title,
    required this.instruction,
    required this.icon,
    required this.isMatch,
  });
}

final List<PoseTarget> kPoseTargets = [
  PoseTarget(
    label: 'depan',
    title: '1. Hadap Depan',
    instruction: 'Posisikan wajah lurus menghadap kamera',
    icon: Icons.face,
    isMatch: (yaw, pitch) => yaw.abs() <= 16 && pitch.abs() <= 16,
  ),
  PoseTarget(
    label: 'kiri',
    title: '2. Tengok Kiri',
    instruction: 'Tengokkan kepala sedikit ke kiri',
    icon: Icons.turn_left,
    isMatch: (yaw, pitch) => (yaw >= -45 && yaw <= -8) || (yaw >= 8 && yaw <= 45),
  ),
  PoseTarget(
    label: 'kanan',
    title: '3. Tengok Kanan',
    instruction: 'Tengokkan kepala sedikit ke kanan',
    icon: Icons.turn_right,
    isMatch: (yaw, pitch) => (yaw >= 8 && yaw <= 45) || (yaw >= -45 && yaw <= -8),
  ),
  PoseTarget(
    label: 'atas',
    title: '4. Angkat Dagu',
    instruction: 'Angkat dagu sedikit ke atas',
    icon: Icons.arrow_upward,
    isMatch: (yaw, pitch) => (pitch >= 6 && pitch <= 35 && yaw.abs() <= 25) || (pitch <= -6 && pitch >= -35 && yaw.abs() <= 25),
  ),
  PoseTarget(
    label: 'bawah',
    title: '5. Tunduk Sedikit',
    instruction: 'Tundukkan kepala sedikit ke bawah',
    icon: Icons.arrow_downward,
    isMatch: (yaw, pitch) => (pitch <= -6 && pitch >= -35 && yaw.abs() <= 25) || (pitch >= 6 && pitch <= 35 && yaw.abs() <= 25),
  ),
];

class CaptureScreen extends ConsumerStatefulWidget {
  final int studentId;
  final String studentName;
  final String nim;
  final bool overwrite;

  const CaptureScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.nim,
    required this.overwrite,
  });

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  CameraController? _cameraController;
  FaceDetector? _faceDetector;
  CameraDescription? _frontCamera;

  bool _isCameraInitialized = false;
  bool _isDetecting = false;
  bool _isCapturing = false;
  int _lastFrameTime = 0;

  int _currentPoseIndex = 0;
  final List<String> _capturedRawPaths = [];

  // Status deteksi real-time
  int _facesDetectedCount = 0;
  bool _isFaceLargeEnough = false;
  bool _isPoseAligned = false;
  double _currentYaw = 0.0;
  double _currentPitch = 0.0;
  String _statusMessage = 'Mempersiapkan kamera...';

  // Timer auto-capture setelah posisi pas
  Timer? _autoCaptureTimer;

  @override
  void initState() {
    super.initState();
    _initDetector();
    _initCamera();
  }

  void _initDetector() {
    final options = FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableClassification: false,
      enableLandmarks: false,
      enableContours: false,
      enableTracking: false,
    );
    _faceDetector = FaceDetector(options: options);
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      _frontCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        _frontCamera!,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _cameraController!.initialize();
      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
      });

      await _cameraController!.startImageStream(_processCameraFrame);
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Gagal menginisialisasi kamera: $e';
        });
      }
    }
  }

  void _processCameraFrame(CameraImage image) async {
    if (_isDetecting || _isCapturing || _faceDetector == null || _frontCamera == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    // Throttle frame processing (~150 ms) sesuai Design Spec 9.3
    if (now - _lastFrameTime < 150) return;
    _lastFrameTime = now;
    _isDetecting = true;

    try {
      final inputImage = _buildInputImageFromCamera(image, _frontCamera!);
      if (inputImage == null) {
        _isDetecting = false;
        return;
      }

      final faces = await _faceDetector!.processImage(inputImage);
      if (!mounted) {
        _isDetecting = false;
        return;
      }

      final targetPose = kPoseTargets[_currentPoseIndex];
      final facesCount = faces.length;

      bool largeEnough = false;
      bool aligned = false;
      double yaw = 0.0;
      double pitch = 0.0;
      String msg = '';

      if (facesCount == 0) {
        msg = 'Wajah tidak terdeteksi. Posisikan wajah di dalam oval.';
      } else if (facesCount > 1) {
        msg = 'Terdeteksi lebih dari 1 wajah ($facesCount). Harap sendiri di depan kamera.';
      } else {
        final face = faces.first;
        yaw = face.headEulerAngleY ?? 0.0;
        pitch = face.headEulerAngleX ?? 0.0;

        // Lebar bbox wajah >= 18% lebar frame
        final minWidth = image.width * 0.18;
        largeEnough = face.boundingBox.width >= minWidth;

        if (!largeEnough) {
          msg = 'Dekatkan wajah ke kamera.';
        } else {
          aligned = targetPose.isMatch(yaw, pitch);
          if (aligned) {
            msg = 'Posisi Pas! Tahan sebentar...';
          } else {
            msg = '${targetPose.instruction} (Yaw: ${yaw.toStringAsFixed(0)}°, Pitch: ${pitch.toStringAsFixed(0)}°)';
          }
        }
      }

      setState(() {
        _facesDetectedCount = facesCount;
        _isFaceLargeEnough = largeEnough;
        _isPoseAligned = aligned;
        _currentYaw = yaw;
        _currentPitch = pitch;
        _statusMessage = msg;
      });

      // Auto-capture jika posisi pas selama 1 detik
      if (aligned && largeEnough && facesCount == 1 && !_isCapturing) {
        if (_autoCaptureTimer == null || !_autoCaptureTimer!.isActive) {
          _autoCaptureTimer = Timer(const Duration(milliseconds: 900), () {
            if (mounted && _isPoseAligned && !_isCapturing) {
              _takePhoto();
            }
          });
        }
      } else {
        _autoCaptureTimer?.cancel();
      }
    } catch (_) {
    } finally {
      _isDetecting = false;
    }
  }

  InputImage? _buildInputImageFromCamera(CameraImage image, CameraDescription camera) {
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation rotation = InputImageRotation.rotation0deg;
    switch (sensorOrientation) {
      case 90:
        rotation = InputImageRotation.rotation90deg;
        break;
      case 180:
        rotation = InputImageRotation.rotation180deg;
        break;
      case 270:
        rotation = InputImageRotation.rotation270deg;
        break;
      default:
        rotation = InputImageRotation.rotation0deg;
    }

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    final bytes = Uint8List.fromList(
      image.planes.fold<List<int>>(<int>[], (list, plane) => list..addAll(plane.bytes)),
    );

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  Future<void> _takePhoto() async {
    if (_isCapturing || _cameraController == null || !_cameraController!.value.isInitialized) return;

    _autoCaptureTimer?.cancel();
    setState(() {
      _isCapturing = true;
      _statusMessage = 'Memeriksa kualitas foto...';
    });

    try {
      // Hentikan stream sementara saat capture
      await _cameraController!.stopImageStream();

      final xFile = await _cameraController!.takePicture();
      final imageBytes = await xFile.readAsBytes();

      // Jalankan pemeriksaan blur dan luminansi di Isolate (Langkah 2)
      final quality = await computeImageQuality(imageBytes);

      if (!quality.isValid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(quality.errorMessage ?? 'Kualitas foto belum memenuhi standar.'),
              backgroundColor: Colors.red.shade800,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        // Ulangi pose yang sama
        if (mounted) {
          setState(() {
            _isCapturing = false;
          });
          await _cameraController!.startImageStream(_processCameraFrame);
        }
        return;
      }

      // Foto lolos uji kualitas
      _capturedRawPaths.add(xFile.path);

      if (_currentPoseIndex + 1 < kPoseTargets.length) {
        // Lanjut ke pose berikutnya
        if (mounted) {
          setState(() {
            _currentPoseIndex++;
            _isCapturing = false;
            _isPoseAligned = false;
          });
          await _cameraController!.startImageStream(_processCameraFrame);
        }
      } else {
        // Kelima pose selesai!
        _finishRegistration();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil foto: $e'), backgroundColor: Colors.red),
        );
        setState(() {
          _isCapturing = false;
        });
        await _cameraController!.startImageStream(_processCameraFrame);
      }
    }
  }

  Future<void> _finishRegistration() async {
    if (!mounted) return;

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
              Expanded(child: Text('Memproses & mengompresi 5 foto wajah...')),
            ],
          ),
        ),
      ),
    );

    final List<String> compressedPaths = [];
    try {
      for (final rawPath in _capturedRawPaths) {
        final compressed = await ImagePrep.compressAndHashFile(rawPath, saveToDisk: true);
        if (compressed.savedPath != null) {
          compressedPaths.add(compressed.savedPath!);
        }
      }

      // Coba kirim langsung ke server agar user mendapat konfirmasi verifikasi AI secara real-time
      final dio = ref.read(apiClientProvider);
      final formData = FormData();
      for (final filePath in compressedPaths) {
        formData.files.add(MapEntry(
          'files',
          await MultipartFile.fromFile(filePath, filename: p.basename(filePath)),
        ));
      }
      formData.fields.add(const MapEntry('pose_labels', 'depan,kiri,kanan,atas,bawah'));

      await dio.post(
        '/students/${widget.studentId}/faces',
        data: formData,
        queryParameters: {'overwrite': widget.overwrite},
      );

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Tutup dialog loading

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Expanded(child: Text('Wajah Berhasil Disimpan!')),
              ],
            ),
            content: Text(
              'Kelima foto wajah untuk "${widget.studentName}" telah berhasil diverifikasi oleh AI InsightFace dan tersimpan di database server.\n\n'
              'Mahasiswa ini sekarang siap dideteksi otomatis (kotak hijau) saat presensi kelas.',
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.go('/');
                },
                child: const Text('Kembali ke Beranda'),
              ),
            ],
          ),
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Tutup loading

      final isNetworkError = e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout;

      if (isNetworkError) {
        // Fallback ke antrean latar belakang jika offline
        final queueWorker = ref.read(queueWorkerProvider);
        await queueWorker.enqueueFaces(
          studentId: widget.studentId,
          filePaths: compressedPaths,
          poseLabels: 'depan,kiri,kanan,atas,bawah',
          overwrite: widget.overwrite,
        );

        if (!mounted) return;
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(child: Text('Tersimpan di Antrean Offline')),
              ],
            ),
            content: Text(
              'Koneksi ke server terputus. Kelima foto wajah "${widget.studentName}" telah disimpan di antrean HP dan akan disinkronkan otomatis saat server online.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.go('/');
                },
                child: const Text('Kembali ke Beranda'),
              ),
            ],
          ),
        );
      } else {
        // Error validasi dari AI Server (misal 422: salah satu pose tidak terdeteksi)
        final msg = ErrorUtils.getErrorMessage(e, 'Gagal memverifikasi wajah');
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red),
                SizedBox(width: 8),
                Expanded(child: Text('Verifikasi AI Gagal')),
              ],
            ),
            content: Text(msg),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  // Reset pose agar bisa ambil ulang
                  setState(() {
                    _currentPoseIndex = 0;
                    _capturedRawPaths.clear();
                    _isCapturing = false;
                    _isPoseAligned = false;
                  });
                  _cameraController?.startImageStream(_processCameraFrame);
                },
                child: const Text('Ambil Ulang Foto'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyelesaikan registrasi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _autoCaptureTimer?.cancel();
    _cameraController?.dispose();
    _faceDetector?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentPose = kPoseTargets[_currentPoseIndex];
    final isAligned = _isPoseAligned && _facesDetectedCount == 1 && _isFaceLargeEnough;

    return Scaffold(
      backgroundColor: Colors.black,
      body: !_isCameraInitialized
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Stack(
              fit: StackFit.expand,
              children: [
                // 1. Kamera Preview
                Center(
                  child: CameraPreview(_cameraController!),
                ),

                // 2. Oval Face Guide Overlay
                CustomPaint(
                  painter: _FaceGuidePainter(isAligned: isAligned),
                ),

                // 3. Top Bar (Header & Pose Steps)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 16,
                  right: 16,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => context.pop(),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.studentName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'NIM: ${widget.nim}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.indigo.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_currentPoseIndex + 1} / ${kPoseTargets.length}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Indikator Titik 5 Pose
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(kPoseTargets.length, (idx) {
                          final isDone = idx < _currentPoseIndex;
                          final isCurrent = idx == _currentPoseIndex;
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: isCurrent ? 28 : 12,
                            height: 10,
                            decoration: BoxDecoration(
                              color: isDone
                                  ? Colors.green
                                  : (isCurrent ? Colors.indigoAccent : Colors.white24),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),

                // 4. Floating Guidance Card
                Positioned(
                  bottom: 120,
                  left: 24,
                  right: 24,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isAligned ? Colors.greenAccent : Colors.white24,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(currentPose.icon, color: isAligned ? Colors.greenAccent : Colors.amber, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              currentPose.title,
                              style: TextStyle(
                                color: isAligned ? Colors.greenAccent : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _statusMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isAligned ? Colors.greenAccent.shade100 : Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        if (_facesDetectedCount == 1) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Sudut: Yaw ${_currentYaw.toStringAsFixed(0)}°, Pitch ${_currentPitch.toStringAsFixed(0)}°',
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // 5. Bottom Controls (Shutter Button - otomatis atau manual)
                Positioned(
                  bottom: 30,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: _isCapturing ? null : _takePhoto,
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isAligned ? Colors.greenAccent : Colors.white70,
                            width: 4,
                          ),
                          color: isAligned ? Colors.greenAccent.shade100 : Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: _isCapturing
                              ? const SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: CircularProgressIndicator(color: Colors.indigo, strokeWidth: 3),
                                )
                              : Icon(
                                  Icons.camera_alt,
                                  size: 36,
                                  color: isAligned ? Colors.green.shade900 : Colors.indigo,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _FaceGuidePainter extends CustomPainter {
  final bool isAligned;

  _FaceGuidePainter({required this.isAligned});

  @override
  void paint(Canvas canvas, Size size) {
    final ovalWidth = size.width * 0.72;
    final ovalHeight = size.height * 0.46;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: ovalWidth,
      height: ovalHeight,
    );

    // Gelapkan area di luar oval
    final backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(rect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, backgroundPaint);

    // Garis batas oval
    final borderPaint = Paint()
      ..color = isAligned ? Colors.greenAccent : Colors.white.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isAligned ? 3.5 : 2.0;

    canvas.drawOval(rect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _FaceGuidePainter oldDelegate) {
    return oldDelegate.isAligned != isAligned;
  }
}
