import 'package:go_router/go_router.dart';
import '../features/home/home_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/classes/class_list_screen.dart';
import '../features/classes/roster_screen.dart';
import '../features/registration/lookup_screen.dart';
import '../features/registration/capture_screen.dart';
import '../features/attendance/attendance_screen.dart';
import '../features/attendance/session_home_screen.dart';
import '../features/attendance/attendance_camera_screen.dart';
import '../features/attendance/attendance_result_screen.dart';
import '../features/attendance/class_points_screen.dart';
import '../features/attendance/models/session_model.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/classes',
      builder: (context, state) => const ClassListScreen(),
    ),
    GoRoute(
      path: '/classes/:id',
      builder: (context, state) {
        final idStr = state.pathParameters['id'] ?? '0';
        final classId = int.tryParse(idStr) ?? 0;
        return RosterScreen(classId: classId);
      },
    ),
    GoRoute(
      path: '/classes/:id/points',
      builder: (context, state) {
        final idStr = state.pathParameters['id'] ?? '0';
        final classId = int.tryParse(idStr) ?? 0;
        return ClassPointsScreen(classId: classId);
      },
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const LookupScreen(),
    ),
    GoRoute(
      path: '/register/capture',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return CaptureScreen(
          studentId: (extra['student_id'] as num?)?.toInt() ?? 0,
          studentName: extra['student_name'] as String? ?? '',
          nim: extra['nim'] as String? ?? '',
          overwrite: extra['overwrite'] as bool? ?? false,
        );
      },
    ),
    GoRoute(
      path: '/attendance',
      builder: (context, state) {
        final classIdStr = state.uri.queryParameters['class_id'];
        final classId = classIdStr != null ? int.tryParse(classIdStr) : null;
        return AttendanceScreen(initialClassId: classId);
      },
    ),
    GoRoute(
      path: '/session/:id',
      builder: (context, state) {
        final idStr = state.pathParameters['id'] ?? '0';
        final sessionId = int.tryParse(idStr) ?? 0;
        final sessionExtra =
            state.extra is SessionData ? state.extra as SessionData : null;
        return SessionHomeScreen(
          sessionId: sessionId,
          initialSession: sessionExtra,
        );
      },
    ),
    GoRoute(
      path: '/session/:id/capture',
      builder: (context, state) {
        final idStr = state.pathParameters['id'] ?? '0';
        final sessionId = int.tryParse(idStr) ?? 0;
        return AttendanceCameraScreen(sessionId: sessionId);
      },
    ),
    GoRoute(
      path: '/session/:id/camera',
      builder: (context, state) {
        final idStr = state.pathParameters['id'] ?? '0';
        final sessionId = int.tryParse(idStr) ?? 0;
        return AttendanceCameraScreen(sessionId: sessionId);
      },
    ),
    GoRoute(
      path: '/session/:id/result',
      builder: (context, state) {
        final idStr = state.pathParameters['id'] ?? '0';
        final sessionId = int.tryParse(idStr) ?? 0;
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final result = extra['result'] as RecognizeResult;
        final imagePath = extra['image_path'] as String? ?? '';
        return AttendanceResultScreen(
          sessionId: sessionId,
          initialResult: result,
          imagePath: imagePath,
        );
      },
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);