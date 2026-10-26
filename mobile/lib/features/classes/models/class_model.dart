class ClassItem {
  final int id;
  final String name;
  final String? code;
  final int studentCount;
  final int facesRegisteredCount;

  ClassItem({
    required this.id,
    required this.name,
    this.code,
    required this.studentCount,
    required this.facesRegisteredCount,
  });

  factory ClassItem.fromJson(Map<String, dynamic> json) {
    return ClassItem(
      id: json['id'] as int,
      name: json['name'] as String,
      code: json['code'] as String?,
      studentCount: (json['student_count'] as num?)?.toInt() ?? 0,
      facesRegisteredCount: (json['faces_registered_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class StudentItem {
  final int id;
  final String nim;
  final String fullName;
  final bool hasFaces;

  StudentItem({
    required this.id,
    required this.nim,
    required this.fullName,
    required this.hasFaces,
  });

  factory StudentItem.fromJson(Map<String, dynamic> json) {
    return StudentItem(
      id: json['id'] as int,
      nim: json['nim'] as String,
      fullName: json['full_name'] as String,
      hasFaces: json['has_faces'] is bool
          ? json['has_faces'] as bool
          : (json['has_faces'] == 1),
    );
  }
}

class ClassDetail {
  final int id;
  final String name;
  final String? code;
  final int studentCount;
  final List<StudentItem> students;

  ClassDetail({
    required this.id,
    required this.name,
    this.code,
    required this.studentCount,
    required this.students,
  });

  factory ClassDetail.fromJson(Map<String, dynamic> json) {
    final list = json['students'] as List<dynamic>? ?? [];
    return ClassDetail(
      id: json['id'] as int,
      name: json['name'] as String,
      code: json['code'] as String?,
      studentCount: (json['student_count'] as num?)?.toInt() ?? list.length,
      students: list
          .map((item) => StudentItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class RosterImportResult {
  final int added;
  final int linkedExisting;
  final int skipped;
  final List<Map<String, dynamic>> errors;
  final List<Map<String, dynamic>> warnings;

  RosterImportResult({
    required this.added,
    required this.linkedExisting,
    required this.skipped,
    required this.errors,
    required this.warnings,
  });

  factory RosterImportResult.fromJson(Map<String, dynamic> json) {
    return RosterImportResult(
      added: (json['added'] as num?)?.toInt() ?? 0,
      linkedExisting: (json['linked_existing'] as num?)?.toInt() ?? 0,
      skipped: (json['skipped'] as num?)?.toInt() ?? 0,
      errors: (json['errors'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      warnings: (json['warnings'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }
}
