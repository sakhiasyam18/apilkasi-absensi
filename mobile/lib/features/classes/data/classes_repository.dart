import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../models/class_model.dart';

final classesRepositoryProvider = Provider<ClassesRepository>((ref) {
  final dio = ref.watch(apiClientProvider);
  return ClassesRepository(dio);
});

final classesListProvider = FutureProvider.autoDispose<List<ClassItem>>((ref) async {
  final repo = ref.watch(classesRepositoryProvider);
  return repo.getClasses();
});

final classDetailProvider = FutureProvider.autoDispose.family<ClassDetail, int>((ref, classId) async {
  final repo = ref.watch(classesRepositoryProvider);
  return repo.getClassDetail(classId);
});

class ClassesRepository {
  final Dio _dio;

  ClassesRepository(this._dio);

  Future<List<ClassItem>> getClasses() async {
    final response = await _dio.get('/classes');
    final list = response.data as List<dynamic>;
    return list.map((item) => ClassItem.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<ClassItem> createClass(String name, String? code) async {
    final response = await _dio.post('/classes', data: {
      'name': name.trim(),
      if (code != null && code.trim().isNotEmpty) 'code': code.trim(),
    });
    return ClassItem.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ClassDetail> getClassDetail(int id) async {
    final response = await _dio.get('/classes/$id');
    return ClassDetail.fromJson(response.data as Map<String, dynamic>);
  }

  Future<RosterImportResult> addStudents(
    int classId,
    List<Map<String, String>> students,
  ) async {
    final response = await _dio.post(
      '/classes/$classId/students',
      data: {'students': students},
    );
    return RosterImportResult.fromJson(response.data as Map<String, dynamic>);
  }

  Future<RosterImportResult> importCsv({
    required int classId,
    required List<int> bytes,
    required String filename,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });

    final response = await _dio.post(
      '/classes/$classId/students/import',
      data: formData,
    );
    return RosterImportResult.fromJson(response.data as Map<String, dynamic>);
  }
}
