import 'dart:ui';

class SessionParticipantItem {
  final int studentId;
  final String fullName;
  final String nim;
  final bool hasFaces;

  SessionParticipantItem({
    required this.studentId,
    required this.fullName,
    required this.nim,
    required this.hasFaces,
  });

  factory SessionParticipantItem.fromJson(Map<String, dynamic> json) {
    return SessionParticipantItem(
      studentId: (json['student_id'] as num?)?.toInt() ?? 0,
      fullName: json['full_name'] as String? ?? '',
      nim: json['nim'] as String? ?? '',
      hasFaces: json['has_faces'] is bool
          ? json['has_faces'] as bool
          : (json['has_faces'] == 1),
    );
  }
}

class IdentifiedParticipant {
  final int studentId;
  final String fullName;
  final String nim;
  final double? score;
  final String method; // 'auto' | 'manual'

  IdentifiedParticipant({
    required this.studentId,
    required this.fullName,
    required this.nim,
    this.score,
    required this.method,
  });

  factory IdentifiedParticipant.fromJson(Map<String, dynamic> json) {
    return IdentifiedParticipant(
      studentId: (json['student_id'] as num?)?.toInt() ?? 0,
      fullName: json['full_name'] as String? ?? '',
      nim: json['nim'] as String? ?? '',
      score: (json['score'] as num?)?.toDouble(),
      method: json['method'] as String? ?? 'auto',
    );
  }
}

class UnidentifiedParticipant {
  final int studentId;
  final String fullName;
  final String nim;
  final bool hasFaces;

  UnidentifiedParticipant({
    required this.studentId,
    required this.fullName,
    required this.nim,
    required this.hasFaces,
  });

  factory UnidentifiedParticipant.fromJson(Map<String, dynamic> json) {
    return UnidentifiedParticipant(
      studentId: (json['student_id'] as num?)?.toInt() ?? 0,
      fullName: json['full_name'] as String? ?? '',
      nim: json['nim'] as String? ?? '',
      hasFaces: json['has_faces'] is bool
          ? json['has_faces'] as bool
          : (json['has_faces'] == 1),
    );
  }
}

class SessionProgressData {
  final int totalParticipants;
  final List<IdentifiedParticipant> identified;
  final List<UnidentifiedParticipant> unidentified;

  SessionProgressData({
    required this.totalParticipants,
    required this.identified,
    required this.unidentified,
  });

  factory SessionProgressData.fromJson(Map<String, dynamic> json) {
    final identList = (json['identified'] as List<dynamic>? ?? [])
        .map((e) => IdentifiedParticipant.fromJson(e as Map<String, dynamic>))
        .toList();
    final unidentList = (json['unidentified'] as List<dynamic>? ?? [])
        .map((e) => UnidentifiedParticipant.fromJson(e as Map<String, dynamic>))
        .toList();

    return SessionProgressData(
      totalParticipants: (json['total_participants'] as num?)?.toInt() ?? 0,
      identified: identList,
      unidentified: unidentList,
    );
  }
}

class CaptureItem {
  final int id;
  final int captureNo;
  final String clientCaptureId;
  final int imageWidth;
  final int imageHeight;
  final String? createdAt;

  CaptureItem({
    required this.id,
    required this.captureNo,
    required this.clientCaptureId,
    required this.imageWidth,
    required this.imageHeight,
    this.createdAt,
  });

  factory CaptureItem.fromJson(Map<String, dynamic> json) {
    return CaptureItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      captureNo: (json['capture_no'] as num?)?.toInt() ?? 0,
      clientCaptureId: json['client_capture_id'] as String? ?? '',
      imageWidth: (json['image_width'] as num?)?.toInt() ?? 0,
      imageHeight: (json['image_height'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] as String?,
    );
  }
}

class SessionData {
  final int id;
  final int classId;
  final String activityName;
  final String sessionDate;
  final String sessionTime;
  final int meetingNumber;
  final String status;
  final int captureCount;
  final int maxCaptures;
  final String? createdAt;
  final String? finalizedAt;
  final List<SessionParticipantItem> participants;
  final int withoutFacesCount;
  final SessionProgressData? progress;
  final List<CaptureItem> captures;

  SessionData({
    required this.id,
    required this.classId,
    required this.activityName,
    required this.sessionDate,
    required this.sessionTime,
    required this.meetingNumber,
    required this.status,
    required this.captureCount,
    required this.maxCaptures,
    this.createdAt,
    this.finalizedAt,
    required this.participants,
    required this.withoutFacesCount,
    this.progress,
    this.captures = const [],
  });

  factory SessionData.fromJson(Map<String, dynamic> json) {
    final participantsList = (json['participants'] as List<dynamic>? ?? [])
        .map((p) => SessionParticipantItem.fromJson(p as Map<String, dynamic>))
        .toList();

    final capturesList = (json['captures'] as List<dynamic>? ?? [])
        .map((c) => CaptureItem.fromJson(c as Map<String, dynamic>))
        .toList();

    final progressData = json['progress'] is Map<String, dynamic>
        ? SessionProgressData.fromJson(json['progress'] as Map<String, dynamic>)
        : null;

    return SessionData(
      id: (json['id'] as num?)?.toInt() ?? 0,
      classId: (json['class_id'] as num?)?.toInt() ?? 0,
      activityName: json['activity_name'] as String? ?? '',
      sessionDate: json['session_date'] as String? ?? '',
      sessionTime: json['session_time'] as String? ?? '',
      meetingNumber: (json['meeting_number'] as num?)?.toInt() ?? 1,
      status: json['status'] as String? ?? 'active',
      captureCount: (json['capture_count'] as num?)?.toInt() ?? 0,
      maxCaptures: (json['max_captures'] as num?)?.toInt() ?? 5,
      createdAt: json['created_at'] as String?,
      finalizedAt: json['finalized_at'] as String?,
      participants: participantsList,
      withoutFacesCount: (json['without_faces_count'] as num?)?.toInt() ?? 0,
      progress: progressData,
      captures: capturesList,
    );
  }
}

class BboxRect {
  final double x;
  final double y;
  final double w;
  final double h;

  BboxRect({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  factory BboxRect.fromJson(Map<String, dynamic> json) {
    return BboxRect(
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      w: (json['w'] as num?)?.toDouble() ?? 0.0,
      h: (json['h'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Rect toRect() => Rect.fromLTWH(x, y, w, h);
}

class FaceBoxResult {
  final int faceId;
  final BboxRect bbox;
  String status; // 'identified' | 'unknown' | 'confirmed'
  int? studentId;
  String? fullName;
  String? nim;
  double? score;

  FaceBoxResult({
    required this.faceId,
    required this.bbox,
    required this.status,
    this.studentId,
    this.fullName,
    this.nim,
    this.score,
  });

  factory FaceBoxResult.fromJson(Map<String, dynamic> json) {
    final bboxMap = json['bbox'] as Map<String, dynamic>? ?? {};
    return FaceBoxResult(
      faceId: (json['face_id'] as num?)?.toInt() ?? 0,
      bbox: BboxRect.fromJson(bboxMap),
      status: json['status'] as String? ?? 'unknown',
      studentId: (json['student_id'] as num?)?.toInt(),
      fullName: json['full_name'] as String?,
      nim: json['nim'] as String?,
      score: (json['score'] as num?)?.toDouble(),
    );
  }
}

class RecognizeResult {
  final int captureId;
  final int captureNo;
  final int maxCaptures;
  final int imageWidth;
  final int imageHeight;
  final List<FaceBoxResult> faces;
  final SessionProgressData progress;

  RecognizeResult({
    required this.captureId,
    required this.captureNo,
    required this.maxCaptures,
    required this.imageWidth,
    required this.imageHeight,
    required this.faces,
    required this.progress,
  });

  factory RecognizeResult.fromJson(Map<String, dynamic> json) {
    final facesList = (json['faces'] as List<dynamic>? ?? [])
        .map((f) => FaceBoxResult.fromJson(f as Map<String, dynamic>))
        .toList();

    final progressMap = json['progress'] as Map<String, dynamic>? ?? {};

    return RecognizeResult(
      captureId: (json['capture_id'] as num?)?.toInt() ?? 0,
      captureNo: (json['capture_no'] as num?)?.toInt() ?? 0,
      maxCaptures: (json['max_captures'] as num?)?.toInt() ?? 5,
      imageWidth: (json['image_width'] as num?)?.toInt() ?? 1440,
      imageHeight: (json['image_height'] as num?)?.toInt() ?? 1920,
      faces: facesList,
      progress: SessionProgressData.fromJson(progressMap),
    );
  }
}

class FinalizeStudentResult {
  final int studentId;
  final String fullName;
  final String nim;
  final String status; // 'hadir' | 'tidak_hadir'
  final String method; // 'auto' | 'manual'
  final int delta;
  final int classTotalPoints;

  FinalizeStudentResult({
    required this.studentId,
    required this.fullName,
    required this.nim,
    required this.status,
    required this.method,
    required this.delta,
    required this.classTotalPoints,
  });

  factory FinalizeStudentResult.fromJson(Map<String, dynamic> json) {
    return FinalizeStudentResult(
      studentId: (json['student_id'] as num?)?.toInt() ?? 0,
      fullName: json['full_name'] as String? ?? '',
      nim: json['nim'] as String? ?? '',
      status: json['status'] as String? ?? 'tidak_hadir',
      method: json['method'] as String? ?? 'auto',
      delta: (json['delta'] as num?)?.toInt() ?? 0,
      classTotalPoints: (json['class_total_points'] as num?)?.toInt() ?? 0,
    );
  }
}

class FinalizeResult {
  final int sessionId;
  final int classId;
  final String status;
  final List<FinalizeStudentResult> results;

  FinalizeResult({
    required this.sessionId,
    required this.classId,
    required this.status,
    required this.results,
  });

  factory FinalizeResult.fromJson(Map<String, dynamic> json) {
    final list = (json['results'] as List<dynamic>? ?? [])
        .map((r) => FinalizeStudentResult.fromJson(r as Map<String, dynamic>))
        .toList();

    return FinalizeResult(
      sessionId: (json['session_id'] as num?)?.toInt() ?? 0,
      classId: (json['class_id'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'final',
      results: list,
    );
  }
}

class StudentPointItem {
  final int studentId;
  final String fullName;
  final String nim;
  final int totalPoints;

  StudentPointItem({
    required this.studentId,
    required this.fullName,
    required this.nim,
    required this.totalPoints,
  });

  factory StudentPointItem.fromJson(Map<String, dynamic> json) {
    return StudentPointItem(
      studentId: (json['student_id'] as num?)?.toInt() ?? 0,
      fullName: json['full_name'] as String? ?? '',
      nim: json['nim'] as String? ?? '',
      totalPoints: (json['total_points'] as num?)?.toInt() ?? 0,
    );
  }
}
