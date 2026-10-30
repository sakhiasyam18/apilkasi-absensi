import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../models/session_model.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  final dio = ref.watch(apiClientProvider);
  return AttendanceRepository(dio);
});

final sessionDetailProvider =
    FutureProvider.autoDispose.family<SessionData, int>((ref, sessionId) async {
  final repo = ref.watch(attendanceRepositoryProvider);
  return repo.getSessionDetail(sessionId);
});

final classPointsProvider = FutureProvider.autoDispose
    .family<List<StudentPointItem>, int>((ref, classId) async {
  final repo = ref.watch(attendanceRepositoryProvider);
  return repo.getClassPoints(classId);
});

class AttendanceRepository {
  final Dio _dio;

  AttendanceRepository(this._dio);

  Future<SessionData> createSession({
    required int classId,
    required String activityName,
    required String sessionDate,
    required String sessionTime,
    required int meetingNumber,
  }) async {
    final response = await _dio.post('/sessions', data: {
      'class_id': classId,
      'activity_name': activityName.trim(),
      'session_date': sessionDate,
      'session_time': sessionTime,
      'meeting_number': meetingNumber,
    });
    return SessionData.fromJson(response.data as Map<String, dynamic>);
  }

  Future<SessionData> getSessionDetail(int sessionId) async {
    final response = await _dio.get('/sessions/$sessionId');
    return SessionData.fromJson(response.data as Map<String, dynamic>);
  }

  Future<RecognizeResult> recognizeAttendance({
    required int sessionId,
    required String clientCaptureId,
    required File imageFile,
    required String sha256Hex,
  }) async {
    final formData = FormData.fromMap({
      'session_id': sessionId,
      'client_capture_id': clientCaptureId,
      'image': await MultipartFile.fromFile(
        imageFile.path,
        filename: '$clientCaptureId.jpg',
      ),
    });

    final response = await _dio.post(
      '/attendance/recognize',
      data: formData,
      options: Options(
        headers: {
          'X-Content-SHA256': sha256Hex,
        },
      ),
    );

    return RecognizeResult.fromJson(response.data as Map<String, dynamic>);
  }

  Future<SessionProgressData> confirmAttendance({
    required int sessionId,
    required int studentId,
    int? faceId,
  }) async {
    final response = await _dio.post(
      '/attendance/confirm',
      data: {
        'session_id': sessionId,
        'student_id': studentId,
        'face_id': ?faceId,
      },
    );
    return SessionProgressData.fromJson(response.data as Map<String, dynamic>);
  }

  Future<FinalizeResult> finalizeSession(int sessionId) async {
    final response = await _dio.post('/sessions/$sessionId/finalize');
    return FinalizeResult.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<StudentPointItem>> getClassPoints(int classId) async {
    final response = await _dio.get(
      '/points',
      queryParameters: {'class_id': classId},
    );
    final list = response.data as List<dynamic>? ?? [];
    return list.map((item) => StudentPointItem.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<SessionData> addSessionParticipant(int sessionId, int studentId) async {
    final response = await _dio.post(
      '/sessions/$sessionId/participants',
      data: {'student_id': studentId},
    );
    return SessionData.fromJson(response.data as Map<String, dynamic>);
  }
}
