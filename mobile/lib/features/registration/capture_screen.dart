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
  final String targetXText; // e.g. "Pitch: ±15°"
  final String targetYText; // e.g. "Yaw: ±15°"
  final String targetZText; // e.g. "Roll: ±18° | Jarak ≥18%"
  final bool Function(double yaw, double pitch, double roll, double distRatio) isMatch;
  final bool Function(double pitch) isXMatch;
  final bool Function(double yaw) isYMatch;
  final bool Function(double roll, double distRatio) isZMatch;

  const PoseTarget({
    required this.label,
    required this.title,
    required this.instruction,
    required this.icon,
    required this.targetXText,
    required this.targetYText,
    required this.targetZText,
    required this.isMatch,
    required this.isXMatch,
    required this.isYMatch,
    required this.isZMatch,
  });
}

final List<PoseTarget> kPoseTargets = [
  PoseTarget(
    label: 'depan',
    title: '1. Hadap Depan',
    instruction: 'Posisikan wajah lurus menghadap kamera',
    icon: Icons.face,
    targetXText: '±15°',
    targetYText: '±15°',
    targetZText: 'Roll ±18° | Jarak ≥18%',
    isXMatch: (pitch) => pitch.abs() <= 16,
    isYMatch: (yaw) => yaw.abs() <= 16,
    isZMatch: (roll, dist) => roll.abs() <= 18 && dist >= 0.18,
    isMatch: (yaw, pitch, roll, dist) =>
        yaw.abs() <= 16 && pitch.abs() <= 16 && roll.abs() <= 18 && dist >= 0.18,
  ),
  PoseTarget(
    label: 'kiri',
    title: '2. Tengok Kiri',
    instruction: 'Tengokkan kepala sedikit ke kiri',
    icon: Icons.turn_left,
    targetXText: '±20°',
    targetYText: '8° s/d 45° (Kiri)',
    targetZText: 'Roll ±20° | Jarak ≥18%',
    isXMatch: (pitch) => pitch.abs() <= 20,
    isYMatch: (yaw) => (yaw >= -45 && yaw <= -8) || (yaw >= 8 && yaw <= 45),
    isZMatch: (roll, dist) => roll.abs() <= 20 && dist >= 0.18,
    isMatch: (yaw, pitch, roll, dist) =>
        ((yaw >= -45 && yaw <= -8) || (yaw >= 8 && yaw <= 45)) &&
        pitch.abs() <= 20 &&
        roll.abs() <= 20 &&
        dist >= 0.18,
  ),
  PoseTarget(
    label: 'kanan',
    title: '3. Tengok Kanan',
    instruction: 'Tengokkan kepala sedikit ke kanan',
    icon: Icons.turn_right,
    targetXText: '±20°',
    targetYText: '8° s/d 45° (Kanan)',
    targetZText: 'Roll ±20° | Jarak ≥18%',
    isXMatch: (pitch) => pitch.abs() <= 20,
    isYMatch: (yaw) => (yaw >= 8 && yaw <= 45) || (yaw >= -45 && yaw <= -8),
    isZMatch: (roll, dist) => roll.abs() <= 20 && dist >= 0.18,
    isMatch: (yaw, pitch, roll, dist) =>
        ((yaw >= 8 && yaw <= 45) || (yaw >= -45 && yaw <= -8)) &&
        pitch.abs() <= 20 &&
        roll.abs() <= 20 &&
        dist >= 0.18,
  ),
  PoseTarget(
    label: 'atas',
    title: '4. Angkat Dagu',
    instruction: 'Angkat dagu sedikit ke atas',
    icon: Icons.arrow_upward,
    targetXText: '+6° s/d +35° (Atas)',
    targetYText: '±25°',
    targetZText: 'Roll ±20° | Jarak ≥18%',
    isXMatch: (pitch) => (pitch >= 6 && pitch <= 35) || (pitch <= -6 && pitch >= -35),
    isYMatch: (yaw) => yaw.abs() <= 25,
    isZMatch: (roll, dist) => roll.abs() <= 20 && dist >= 0.18,
    isMatch: (yaw, pitch, roll, dist) =>
        ((pitch >= 6 && pitch <= 35) || (pitch <= -6 && pitch >= -35)) &&
        yaw.abs() <= 25 &&
        roll.abs() <= 20 &&
        dist >= 0.18,
  ),
  PoseTarget(
    label: 'bawah',
    title: '5. Tunduk Sedikit',
    instruction: 'Tundukkan kepala sedikit ke bawah',
    icon: Icons.arrow_downward,
    targetXText: '-6° s/d -35° (Bawah)',
    targetYText: '±25°',
    targetZText: 'Roll ±20° | Jarak ≥18%',
    isXMatch: (pitch) => (pitch <= -6 && pitch >= -35) || (pitch >= 6 && pitch <= 35),
    isYMatch: (yaw) => yaw.abs() <= 25,
    isZMatch: (roll, dist) => roll.abs() <= 20 && dist >= 0.18,
    isMatch: (yaw, pitch, roll, dist) =>
        ((pitch <= -6 && pitch >= -35) || (pitch >= 6 && pitch <= 35)) &&
        yaw.abs() <= 25 &&
        roll.abs() <= 20 &&
        dist >= 0.18,
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
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  CameraDescription? get _currentCamera =>
      _cameras.isNotEmpty ? _cameras[_selectedCameraIndex] : null;

  bool _isCameraInitialized = false;
  bool _isDetecting = false;
  bool _isCapturing = false;
  int _lastFrameTime = 0;

  int _currentPoseIndex = 0;
  final List<String> _capturedRawPaths = [];

  // Status deteksi real-time Sumbu X, Y, Z
  int _facesDetectedCount = 0;
  bool _isFaceLargeEnough = false;
  bool _isPoseAligned = false;
  bool _isXMatch = false;
  bool _isYMatch = false;
  bool _isZMatch = false;
  double _currentYaw = 0.0;
  double _currentPitch = 0.0;
  double _currentRoll = 0.0;
  double _currentDistRatio = 0.0;
  String _statusMessage = 'Mempersiapkan sensor kamera...';

  // Countdown & Auto-capture progress (0.0 s/d 1.0)
  Timer? _countdownTicker;
  double _autoCaptureProgress = 0.0;

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
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _statusMessage = 'Kamera tidak ditemukan pada perangkat.';
          });
        }
        return;
      }
      final frontIdx = _cameras.indexWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
      );
      final initialIdx = frontIdx != -1 ? frontIdx : 0;
      await _startCamera(initialIdx);
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Gagal inisialisasi kamera: $e';
        });
      }
    }
  }

  Future<void> _startCamera(int cameraIndex) async {
    try {
      if (_cameraController != null) {
        if (_cameraController!.value.isStreamingImages) {
          await _cameraController!.stopImageStream();
        }
        await _cameraController!.dispose();
        _cameraController = null;
      }

      _selectedCameraIndex = cameraIndex;
      final cam = _cameras[_selectedCameraIndex];

      final controller = CameraController(
        cam,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      _cameraController = controller;
      await controller.initialize();
      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
      });

      await controller.startImageStream(_processCameraFrame);
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Gagal inisialisasi kamera: $e';
        });
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _isCapturing) return;
    _countdownTicker?.cancel();
    _autoCaptureProgress = 0.0;

    final nextIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _startCamera(nextIndex);
  }

  void _processCameraFrame(CameraImage image) async {
    final curCam = _currentCamera;
    if (_isDetecting || _isCapturing || _faceDetector == null || curCam == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    // Throttle frame processing (~120 ms)
    if (now - _lastFrameTime < 120) return;
    _lastFrameTime = now;
    _isDetecting = true;

    try {
      final inputImage = _buildInputImageFromCamera(image, curCam);
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
      bool isX = false;
      bool isY = false;
      bool isZ = false;
      bool aligned = false;
      double yaw = 0.0;
      double pitch = 0.0;
      double roll = 0.0;
      double distRatio = 0.0;
      String msg = '';

      if (facesCount == 0) {
        msg = 'Posisikan wajah ke dalam area sensor kamera';
      } else if (facesCount > 1) {
        msg = 'Terdeteksi $facesCount wajah. Pastikan hanya 1 wajah di depan kamera.';
      } else {
        final face = faces.first;
        yaw = face.headEulerAngleY ?? 0.0;
        pitch = face.headEulerAngleX ?? 0.0;
        roll = face.headEulerAngleZ ?? 0.0;

        // Ukuran wajah relatif terhadap frame
        final frameDim = (image.width < image.height ? image.width : image.height).toDouble();
        distRatio = frameDim > 0 ? (face.boundingBox.width / frameDim) : 0.0;

        isX = targetPose.isXMatch(pitch);
        isY = targetPose.isYMatch(yaw);
        isZ = targetPose.isZMatch(roll, distRatio);
        largeEnough = distRatio >= 0.18;
        aligned = targetPose.isMatch(yaw, pitch, roll, distRatio);

        if (!largeEnough) {
          msg = 'Dekatkan wajah sedikit ke kamera (Z-Distance kurang)';
        } else if (aligned) {
          msg = 'Target Terkunci! Mengambil foto otomatis...';
        } else {
          final List<String> pendingAxes = [];
          if (!isX) pendingAxes.add('X (Pitch)');
          if (!isY) pendingAxes.add('Y (Yaw)');
          if (!isZ) pendingAxes.add('Z (Roll/Jarak)');
          msg = '${targetPose.instruction} • Sesuaikan sumbu ${pendingAxes.join(', ')}';
        }
      }

      setState(() {
        _facesDetectedCount = facesCount;
        _isFaceLargeEnough = largeEnough;
        _isPoseAligned = aligned;
        _isXMatch = isX;
        _isYMatch = isY;
        _isZMatch = isZ;
        _currentYaw = yaw;
        _currentPitch = pitch;
        _currentRoll = roll;
        _currentDistRatio = distRatio;
        _statusMessage = msg;
      });

      // Auto-Capture Countdown (~800ms) saat semua sumbu X, Y, Z terkunci
      if (aligned && facesCount == 1 && !_isCapturing) {
        if (_countdownTicker == null || !_countdownTicker!.isActive) {
          _countdownTicker = Timer.periodic(const Duration(milliseconds: 50), (timer) {
            if (!mounted) {
              timer.cancel();
              return;
            }
            if (_isPoseAligned && !_isCapturing) {
              setState(() {
                _autoCaptureProgress = (_autoCaptureProgress + (50 / 800)).clamp(0.0, 1.0);
              });
              if (_autoCaptureProgress >= 1.0) {
                timer.cancel();
                _takePhoto();
              }
            } else {
              timer.cancel();
              setState(() {
                _autoCaptureProgress = 0.0;
              });
            }
          });
        }
      } else {
        if (_countdownTicker?.isActive ?? false) {
          _countdownTicker?.cancel();
        }
        if (_autoCaptureProgress > 0.0) {
          setState(() {
            _autoCaptureProgress = 0.0;
          });
        }
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

    _countdownTicker?.cancel();
    setState(() {
      _isCapturing = true;
      _autoCaptureProgress = 0.0;
      _statusMessage = 'Foto diambil! Memeriksa kualitas (anti-blur)...';
    });

    try {
      // Hentikan stream sementara saat capture
      await _cameraController!.stopImageStream();

      final xFile = await _cameraController!.takePicture();
      final imageBytes = await xFile.readAsBytes();

      // Jalankan pemeriksaan blur dan luminansi di Isolate
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
              'Mahasiswa ini sekarang siap dideteksi otomatis saat presensi kelas.',
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
    _countdownTicker?.cancel();
    _cameraController?.dispose();
    _faceDetector?.close();
    super.dispose();
  }

  Widget _buildAxisRow({
    required String axisLabel,
    required String currentVal,
    required String targetVal,
    required bool isMatch,
    required IconData icon,
  }) {
    final color = isMatch ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          SizedBox(
            width: 78,
            child: Text(
              axisLabel,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: RichText(
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Dapat: ',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                  ),
                  TextSpan(
                    text: '$currentVal  ',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  TextSpan(
                    text: 'Target: ',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                  ),
                  TextSpan(
                    text: targetVal,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color.withValues(alpha: 0.6), width: 1),
            ),
            child: Text(
              isMatch ? 'PAS' : 'SESUAIKAN',
              style: TextStyle(
                color: color,
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveSensorHud(PoseTarget currentPose) {
    final isLocked = _isPoseAligned && _facesDetectedCount == 1 && _isFaceLargeEnough;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xDD0D1117),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLocked ? const Color(0xFF10B981) : Colors.white24,
          width: isLocked ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isLocked ? const Color(0x3310B981) : Colors.black45,
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header SENSOR HUD
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isLocked ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  boxShadow: [
                    BoxShadow(
                      color: (isLocked ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.8),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'LIVE SENSOR HUD (X, Y, Z)',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (isLocked ? const Color(0xFF10B981) : Colors.blueGrey).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isLocked ? Icons.lock : Icons.lock_open,
                      size: 11,
                      color: isLocked ? const Color(0xFF10B981) : Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isLocked ? 'TERKUNCI' : 'PELACAKAN',
                      style: TextStyle(
                        color: isLocked ? const Color(0xFF10B981) : Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 6),

          // Baris Sumbu X: Pitch
          _buildAxisRow(
            axisLabel: 'X (Pitch)',
            currentVal: '${_currentPitch >= 0 ? '+' : ''}${_currentPitch.toStringAsFixed(0)}°',
            targetVal: currentPose.targetXText,
            isMatch: _isXMatch,
            icon: Icons.height,
          ),

          // Baris Sumbu Y: Yaw
          _buildAxisRow(
            axisLabel: 'Y (Yaw)',
            currentVal: '${_currentYaw >= 0 ? '+' : ''}${_currentYaw.toStringAsFixed(0)}°',
            targetVal: currentPose.targetYText,
            isMatch: _isYMatch,
            icon: Icons.swap_horiz,
          ),

          // Baris Sumbu Z: Roll & Kedalaman / Jarak
          _buildAxisRow(
            axisLabel: 'Z (Roll/Jrk)',
            currentVal: '${_currentRoll.toStringAsFixed(0)}° | ${(_currentDistRatio * 100).toStringAsFixed(0)}%',
            targetVal: currentPose.targetZText,
            isMatch: _isZMatch,
            icon: Icons.aspect_ratio,
          ),

          const SizedBox(height: 8),

          // Status & Progress Auto-Capture Bar
          if (isLocked) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _autoCaptureProgress,
                minHeight: 5,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Posisi Sempurna! Otomatis mengambil foto dalam ${((1.0 - _autoCaptureProgress) * 0.8).toStringAsFixed(1)}s...',
              style: const TextStyle(
                color: Color(0xFF10B981),
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ] else ...[
            Text(
              _statusMessage,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 11.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentPose = kPoseTargets[_currentPoseIndex];
    final isAligned = _isPoseAligned && _facesDetectedCount == 1 && _isFaceLargeEnough;

    return Scaffold(
      backgroundColor: Colors.black,
      body: !_isCameraInitialized || _cameraController == null
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
                  painter: _FaceGuidePainter(
                    isAligned: isAligned,
                    hasFace: _facesDetectedCount > 0,
                  ),
                ),

                // 3. Top Bar (Header, Flip Camera & Pose Steps)
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
                                    fontSize: 15,
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
                          // Tombol Ganti Kamera Depan / Belakang
                          IconButton(
                            icon: const Icon(Icons.flip_camera_android_rounded, color: Colors.white),
                            tooltip: 'Ganti Kamera',
                            onPressed: _switchCamera,
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.indigo.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_currentPoseIndex + 1} / ${kPoseTargets.length}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Indikator Titik 5 Pose
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(kPoseTargets.length, (idx) {
                          final isDone = idx < _currentPoseIndex;
                          final isCurrent = idx == _currentPoseIndex;
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: isCurrent ? 26 : 10,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isDone
                                  ? const Color(0xFF10B981)
                                  : (isCurrent ? Colors.indigoAccent : Colors.white24),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),

                // 4. Live Sensor HUD Card (X, Y, Z)
                Positioned(
                  bottom: 116,
                  left: 16,
                  right: 16,
                  child: _buildLiveSensorHud(currentPose),
                ),

                // 5. Bottom Controls (Shutter Button - otomatis auto-capture atau manual klik)
                Positioned(
                  bottom: 24,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: _isCapturing ? null : _takePhoto,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Lingkaran Progres Countdown Auto-Capture
                          SizedBox(
                            width: 82,
                            height: 82,
                            child: CircularProgressIndicator(
                              value: isAligned ? _autoCaptureProgress : 0.0,
                              strokeWidth: 4,
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                              backgroundColor: Colors.white24,
                            ),
                          ),
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isAligned ? const Color(0xFF10B981) : Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: _isCapturing
                                  ? const SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                    )
                                  : Icon(
                                      Icons.camera_alt,
                                      size: 32,
                                      color: isAligned ? Colors.white : Colors.indigo,
                                    ),
                            ),
                          ),
                        ],
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
  final bool hasFace;

  _FaceGuidePainter({required this.isAligned, required this.hasFace});

  @override
  void paint(Canvas canvas, Size size) {
    final ovalWidth = size.width * 0.72;
    final ovalHeight = size.height * 0.44;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.38),
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

    // Garis batas oval glow
    final Color borderColor = isAligned
        ? const Color(0xFF10B981)
        : (hasFace ? const Color(0xFFF59E0B) : Colors.white.withValues(alpha: 0.7));

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isAligned ? 3.5 : 2.0;

    canvas.drawOval(rect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _FaceGuidePainter oldDelegate) {
    return oldDelegate.isAligned != isAligned || oldDelegate.hasFace != hasFace;
  }
}
