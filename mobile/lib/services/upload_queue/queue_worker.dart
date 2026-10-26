import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/api/api_client.dart';
import '../../core/config/app_config.dart';
import 'queue_db.dart';

final queueDatabaseProvider = Provider<QueueDatabase>((ref) {
  return QueueDatabase();
});

final queueWorkerProvider = Provider<QueueWorker>((ref) {
  final dio = ref.watch(apiClientProvider);
  final db = ref.watch(queueDatabaseProvider);
  final worker = QueueWorker(dio: dio, db: db);
  worker.start();
  ref.onDispose(() => worker.stop());
  return worker;
});

class QueueWorker {
  final Dio dio;
  final QueueDatabase db;

  Timer? _timer;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  bool _isProcessing = false;

  QueueWorker({required this.dio, required this.db});

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => processQueue());

    _connSub?.cancel();
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection) {
        processQueue();
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _connSub?.cancel();
  }

  /// Masukkan pendaftaran 5 foto wajah ke antrean upload
  Future<QueueItem> enqueueFaces({
    required int studentId,
    required List<String> filePaths,
    required String poseLabels,
    required bool overwrite,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final item = QueueItem(
      id: const Uuid().v4(),
      type: 'faces',
      endpoint: '/students/$studentId/faces',
      payload: {
        'student_id': studentId,
        'file_paths': filePaths,
        'pose_labels': poseLabels,
        'overwrite': overwrite,
      },
      attempts: 0,
      nextAttemptAt: now,
      status: 'pending',
      createdAt: now,
    );

    await db.enqueue(item);
    // Segera proses antrean setelah dimasukkan
    processQueue();
    return item;
  }

  /// Eksekusi pemrosesan item dalam antrean
  Future<void> processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final pendingItems = await db.getPendingItems(nowMs: now);

      for (final item in pendingItems) {
        await _processItem(item);
      }
    } catch (e) {
      debugPrint('[QueueWorker] Error processing queue: $e');
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _processItem(QueueItem item) async {
    try {
      if (item.type == 'faces') {
        final filePaths = (item.payload['file_paths'] as List).cast<String>();
        final poseLabels = item.payload['pose_labels'] as String;
        final overwrite = item.payload['overwrite'] as bool? ?? false;

        final formData = FormData();
        for (final filePath in filePaths) {
          final file = File(filePath);
          if (await file.exists()) {
            formData.files.add(MapEntry(
              'files',
              await MultipartFile.fromFile(
                filePath,
                filename: p.basename(filePath),
              ),
            ));
          } else {
            throw Exception('File gambar tidak ditemukan: $filePath');
          }
        }

        formData.fields.add(MapEntry('pose_labels', poseLabels));

        final response = await dio.post(
          item.endpoint,
          data: formData,
          queryParameters: {'overwrite': overwrite},
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          debugPrint('[QueueWorker] Item ${item.id} berhasil diunggah.');
          await db.updateItem(item.copyWith(status: 'done'));
          // Hapus file sementara setelah berhasil diunggah
          for (final fp in filePaths) {
            try {
              final f = File(fp);
              if (await f.exists()) await f.delete();
            } catch (_) {}
          }
          return;
        }
      }
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final errData = e.response?.data;
      final detail = errData is Map ? errData['detail'] : null;
      final errCode = detail is Map ? detail['code'] : null;

      // Aturan BR-13: Jika 4xx selain checksum_mismatch, jangan di-retry
      if (statusCode != null && statusCode >= 400 && statusCode < 500 && errCode != 'checksum_mismatch') {
        debugPrint('[QueueWorker] 4xx Client Error (${e.response?.statusCode}), job ${item.id} dihentikan.');
        await db.updateItem(item.copyWith(status: 'failed'));
        return;
      }

      // Retry dengan exponential backoff: 1, 2, 4, 8, 16 detik
      final nextAttemptCount = item.attempts + 1;
      if (nextAttemptCount >= AppConfig.maxRetryAttempts) {
        debugPrint('[QueueWorker] Batas retry tercapai (${AppConfig.maxRetryAttempts}), job ${item.id} gagal.');
        await db.updateItem(item.copyWith(
          attempts: nextAttemptCount,
          status: 'failed',
        ));
      } else {
        // Backoff: 1s, 2s, 4s, 8s, 16s -> pow(2, attempts) detik
        final backoffSeconds = pow(2, nextAttemptCount - 1).toInt();
        final nextAttemptAt = DateTime.now().millisecondsSinceEpoch + (backoffSeconds * 1000);
        debugPrint('[QueueWorker] Retry #$nextAttemptCount dalam ${backoffSeconds}s untuk job ${item.id}');
        await db.updateItem(item.copyWith(
          attempts: nextAttemptCount,
          nextAttemptAt: nextAttemptAt,
          status: 'pending',
        ));
      }
    } catch (e) {
      debugPrint('[QueueWorker] General error on item ${item.id}: $e');
      final nextAttemptCount = item.attempts + 1;
      if (nextAttemptCount >= AppConfig.maxRetryAttempts) {
        await db.updateItem(item.copyWith(
          attempts: nextAttemptCount,
          status: 'failed',
        ));
      } else {
        final backoffSeconds = pow(2, nextAttemptCount - 1).toInt();
        final nextAttemptAt = DateTime.now().millisecondsSinceEpoch + (backoffSeconds * 1000);
        await db.updateItem(item.copyWith(
          attempts: nextAttemptCount,
          nextAttemptAt: nextAttemptAt,
          status: 'pending',
        ));
      }
    }
  }
}
