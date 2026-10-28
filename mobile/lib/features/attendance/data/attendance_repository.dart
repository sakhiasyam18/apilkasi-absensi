import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../models/session_model.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  final dio = ref.watch(apiClientProvider);
  return AttendanceRepository(dio);
});

final sessionDetailProvider = FutureProvider.autoDispose.family<SessionData, int>((ref, sessionId) async {
  final repo = ref.watch(attendanceRepositoryProvider);
  return repo.getSessionDetail(sessionId);
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
}
