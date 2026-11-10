import 'dart:io';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/error_utils.dart';
import '../../core/utils/image_prep.dart';
import 'data/attendance_repository.dart';

class AttendanceCameraScreen extends ConsumerStatefulWidget {
  final int sessionId;

  const AttendanceCameraScreen({super.key, required this.sessionId});

  @override
  ConsumerState<AttendanceCameraScreen> createState() =>
      _AttendanceCameraScreenState();
}

class _AttendanceCameraScreenState
    extends ConsumerState<AttendanceCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  CameraDescription? get _currentCamera =>
      _cameras.isNotEmpty ? _cameras[_selectedCameraIndex] : null;

  bool _isInitializing = true;
  bool _isProcessing = false;
  String? _statusMessage;
  FlashMode _flashMode = FlashMode.off;

  // ML Kit Live Multi-Face Detection
  FaceDetector? _faceDetector;
  bool _isDetecting = false;
  int _lastFrameTime = 0;
  List<Rect> _detectedFaceRects = [];
  Size? _inputImageSize;
  InputImageRotation? _inputImageRotation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDetector();
    _initializeCamera();
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _faceDetector?.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _isInitializing = true;
      _statusMessage = 'Menyiapkan kamera kelas...';
    });

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _isInitializing = false;
          _statusMessage = 'Tidak ada kamera terdeteksi pada perangkat ini.';
        });
        return;
      }

      // Default gunakan kamera belakang untuk foto grup kelas
      int backCameraIdx = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      _selectedCameraIndex = backCameraIdx != -1 ? backCameraIdx : 0;

      await _startController(_cameras[_selectedCameraIndex]);
    } catch (e) {
      setState(() {
        _isInitializing = false;
        _statusMessage = 'Gagal mengakses kamera: $e';
      });
    }
  }

  Future<void> _startController(CameraDescription camera) async {
    try {
      if (_controller != null) {
        if (_controller!.value.isStreamingImages) {
          await _controller!.stopImageStream();
        }
        await _controller!.dispose();
        _controller = null;
      }

      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      _controller = controller;

      await controller.initialize();
      await controller.setFlashMode(_flashMode);

      if (mounted) {
        setState(() {
          _isInitializing = false;
          _statusMessage = null;
        });
      }

      // Mulai deteksi wajah live stream
      await controller.startImageStream(_processLiveAttendanceFrame);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _statusMessage = 'Gagal inisialisasi controller: $e';
        });
      }
    }
  }

  void _processLiveAttendanceFrame(CameraImage image) async {
    final cam = _currentCamera;
    if (_isDetecting || _isProcessing || _faceDetector == null || cam == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    // Throttle frame processing (~150 ms)
    if (now - _lastFrameTime < 150) return;
    _lastFrameTime = now;
    _isDetecting = true;

    try {
      final inputImage = _buildInputImage(image, cam);
      if (inputImage == null) {
        _isDetecting = false;
        return;
      }

      final faces = await _faceDetector!.processImage(inputImage);
      if (!mounted) {
        _isDetecting = false;
        return;
      }

      final rects = faces.map((f) => f.boundingBox).toList();

      setState(() {
        _detectedFaceRects = rects;
        _inputImageSize = inputImage.metadata?.size;
        _inputImageRotation = inputImage.metadata?.rotation;
      });
    } catch (_) {
    } finally {
      _isDetecting = false;
    }
  }

  InputImage? _buildInputImage(CameraImage image, CameraDescription camera) {
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

  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final nextMode = _flashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;
    try {
      await _controller!.setFlashMode(nextMode);
      setState(() {
        _flashMode = nextMode;
      });
    } catch (_) {}
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _isProcessing) return;
    final nextIndex = (_selectedCameraIndex + 1) % _cameras.length;
    _selectedCameraIndex = nextIndex;
    _detectedFaceRects.clear();
    await _startController(_cameras[_selectedCameraIndex]);
  }

  Future<void> _takeAttendancePhoto() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Mengambil foto dan memproses AI...';
    });

    try {
      // 1. Hentikan stream sementara saat capture
      if (_controller!.value.isStreamingImages) {
        await _controller!.stopImageStream();
      }

      // 2. Ambil foto asli dari kamera
      final xFile = await _controller!.takePicture();

      // 3. Kompresi gambar sesuai standar Section 9.4 (Auto EXIF orientation, maxUploadSide = 1920)
      setState(() {
        _statusMessage = 'Mengompresi dan menyiapkan gambar...';
      });

      final prepResult = await ImagePrep.compressAndHashFile(
        xFile.path,
        saveToDisk: true,
      );

      final clientCaptureId = const Uuid().v4();
      final compressedFile = File(prepResult.savedPath ?? xFile.path);

      // 4. Kirim ke backend POST /attendance/recognize
      setState(() {
        _statusMessage = 'Menganalisis presensi dengan AI InsightFace...';
      });

      final repo = ref.read(attendanceRepositoryProvider);
      final recognizeResult = await repo.recognizeAttendance(
        sessionId: widget.sessionId,
        clientCaptureId: clientCaptureId,
        imageFile: compressedFile,
        sha256Hex: prepResult.sha256Hex,
      );

      // 5. Invalidate provider sesi agar daftar terbaru tersinkronisasi
      ref.invalidate(sessionDetailProvider(widget.sessionId));

      if (!mounted) return;

      // 6. Buka layar hasil pengenalan (AttendanceResultScreen)
      context.push(
        '/session/${widget.sessionId}/result',
        extra: {
          'result': recognizeResult,
          'image_path': compressedFile.path,
        },
      );
    } on DioException catch (e) {
      final msg = ErrorUtils.getErrorMessage(e, 'Gagal mengenali presensi wajah');
      if (mounted) {
        _showErrorDialog(msg);
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Terjadi kesalahan: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = null;
        });
        // Restart stream jika controller masih aktif dan belum di-dispose
        if (_controller != null &&
            _controller!.value.isInitialized &&
            !_controller!.value.isStreamingImages) {
          try {
            await _controller!.startImageStream(_processLiveAttendanceFrame);
          } catch (_) {}
        }
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Expanded(child: Text('Gagal Memproses')),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionDetailProvider(widget.sessionId));
    final curCam = _currentCamera;
    final isFront = curCam?.lensDirection == CameraLensDirection.front;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Kamera Presensi Kelas'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
              _flashMode == FlashMode.torch ? Icons.flash_on : Icons.flash_off,
              color: _flashMode == FlashMode.torch ? Colors.amber : Colors.white,
            ),
            tooltip: 'Lampu Kilat',
            onPressed: _toggleFlash,
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_android_rounded),
            tooltip: 'Ganti Kamera Depan/Belakang',
            onPressed: _switchCamera,
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera Preview
          if (_isInitializing || _controller == null || !_controller!.value.isInitialized)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    _statusMessage ?? 'Menyiapkan kamera...',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            )
          else
            Center(
              child: CameraPreview(_controller!),
            ),

          // 2. Live Face Circles ("Bunder-Bunder Wajah" Overlay)
          if (!_isInitializing &&
              _controller != null &&
              _controller!.value.isInitialized &&
              _inputImageSize != null &&
              _detectedFaceRects.isNotEmpty)
            IgnorePointer(
              child: CustomPaint(
                painter: _LiveFacesPainter(
                  faces: _detectedFaceRects,
                  imageSize: _inputImageSize!,
                  rotation: _inputImageRotation ?? InputImageRotation.rotation0deg,
                  isFrontCamera: isFront,
                ),
              ),
            ),

          // 3. Grid Panduan Komposisi Lembut
          IgnorePointer(
            child: CustomPaint(
              painter: _ClassroomGridPainter(),
            ),
          ),

          // 4. Header Info Sesi & Indikator Wajah Terdeteksi
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                sessionAsync.when(
                  data: (session) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                session.activityName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'P${session.meetingNumber} • ${session.participants.length} Mahasiswa',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.indigoAccent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Foto: ${session.captureCount} / ${session.maxCaptures}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 8),

                // Live Chip: Jumlah Wajah Terdeteksi Live ("Bunder-Bunder Wajah")
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _detectedFaceRects.isNotEmpty
                        ? const Color(0xCC064E3B)
                        : Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _detectedFaceRects.isNotEmpty
                          ? const Color(0xFF10B981)
                          : Colors.white24,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _detectedFaceRects.isNotEmpty
                              ? const Color(0xFF10B981)
                              : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _detectedFaceRects.isNotEmpty
                            ? 'Live AI: ${_detectedFaceRects.length} Wajah Terdeteksi'
                            : 'Mencari wajah mahasiswa di kelas...',
                        style: TextStyle(
                          color: _detectedFaceRects.isNotEmpty
                              ? const Color(0xFF6EE7B7)
                              : Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 5. Petunjuk Komposisi Bawah
          Positioned(
            bottom: 116,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _detectedFaceRects.isNotEmpty ? Icons.check_circle : Icons.info_outline,
                    color: _detectedFaceRects.isNotEmpty ? const Color(0xFF10B981) : Colors.amber,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _detectedFaceRects.isNotEmpty
                          ? 'Wajah ditandai lingkaran live. Tekan tombol kamera untuk mengenali!'
                          : 'Arahkan kamera ke seluruh mahasiswa dalam ruangan kelas',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 6. Tombol Shutter Bawah
          Positioned(
            bottom: 26,
            left: 0,
            right: 0,
            child: Center(
              child: _isProcessing
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.indigoAccent),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Flexible(
                            child: Text(
                              _statusMessage ?? 'Memproses AI...',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : GestureDetector(
                      onTap: _takeAttendancePhoto,
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _detectedFaceRects.isNotEmpty
                                ? const Color(0xFF10B981)
                                : Colors.white,
                            width: 4,
                          ),
                          color: _detectedFaceRects.isNotEmpty
                              ? const Color(0x3310B981)
                              : Colors.white24,
                        ),
                        child: Center(
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _detectedFaceRects.isNotEmpty
                                  ? const Color(0xFF10B981)
                                  : Colors.white,
                            ),
                            child: Icon(
                              Icons.camera_alt,
                              size: 32,
                              color: _detectedFaceRects.isNotEmpty ? Colors.white : Colors.indigo,
                            ),
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

class _LiveFacesPainter extends CustomPainter {
  final List<Rect> faces;
  final Size imageSize;
  final InputImageRotation rotation;
  final bool isFrontCamera;

  _LiveFacesPainter({
    required this.faces,
    required this.imageSize,
    required this.rotation,
    required this.isFrontCamera,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final ringPaint = Paint()
      ..color = const Color(0xFF10B981)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final glowPaint = Paint()
      ..color = const Color(0x4410B981)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0;

    final dotPaint = Paint()
      ..color = const Color(0xFF6EE7B7)
      ..style = PaintingStyle.fill;

    // Hitung orientasi rotasi kamera terhadap canvas layar
    final bool isRotated = rotation == InputImageRotation.rotation90deg ||
        rotation == InputImageRotation.rotation270deg;

    final double sourceWidth = isRotated ? imageSize.height : imageSize.width;
    final double sourceHeight = isRotated ? imageSize.width : imageSize.height;

    final double scaleX = size.width / sourceWidth;
    final double scaleY = size.height / sourceHeight;

    for (final faceRect in faces) {
      double left = faceRect.left;
      double top = faceRect.top;
      double right = faceRect.right;
      double bottom = faceRect.bottom;

      // Transformasi koordinat sesuai orientasi dan kamera depan/belakang
      if (isFrontCamera) {
        final mirroredLeft = sourceWidth - right;
        final mirroredRight = sourceWidth - left;
        left = mirroredLeft;
        right = mirroredRight;
      }

      final double renderLeft = left * scaleX;
      final double renderTop = top * scaleY;
      final double renderWidth = (right - left).abs() * scaleX;
      final double renderHeight = (bottom - top).abs() * scaleY;

      final center = Offset(renderLeft + renderWidth / 2, renderTop + renderHeight / 2);
      final radius = max(renderWidth, renderHeight) * 0.58;

      // Gambar lingkaran luar glow & lingkaran utama ("Bunder-bunder Wajah")
      canvas.drawCircle(center, radius + 2, glowPaint);
      canvas.drawCircle(center, radius, ringPaint);

      // Gambar 4 titik target penanda di sekeliling lingkaran
      canvas.drawCircle(Offset(center.dx, center.dy - radius), 3.0, dotPaint);
      canvas.drawCircle(Offset(center.dx, center.dy + radius), 3.0, dotPaint);
      canvas.drawCircle(Offset(center.dx - radius, center.dy), 3.0, dotPaint);
      canvas.drawCircle(Offset(center.dx + radius, center.dy), 3.0, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LiveFacesPainter oldDelegate) {
    return oldDelegate.faces != faces || oldDelegate.isFrontCamera != isFrontCamera;
  }
}

class _ClassroomGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Garis 1/3 vertikal
    canvas.drawLine(
      Offset(size.width / 3, 0),
      Offset(size.width / 3, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 2 / 3, 0),
      Offset(size.width * 2 / 3, size.height),
      paint,
    );

    // Garis 1/3 horizontal
    canvas.drawLine(
      Offset(0, size.height / 3),
      Offset(size.width, size.height / 3),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height * 2 / 3),
      Offset(size.width, size.height * 2 / 3),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
