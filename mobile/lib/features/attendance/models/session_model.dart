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
  final List<SessionParticipantItem> participants;
  final int withoutFacesCount;

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
    required this.participants,
    required this.withoutFacesCount,
  });

  factory SessionData.fromJson(Map<String, dynamic> json) {
    final participantsList = (json['participants'] as List<dynamic>? ?? [])
        .map((p) => SessionParticipantItem.fromJson(p as Map<String, dynamic>))
        .toList();

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
      participants: participantsList,
      withoutFacesCount: (json['without_faces_count'] as num?)?.toInt() ?? 0,
    );
  }
}
