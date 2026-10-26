import 'package:go_router/go_router.dart';
import '../features/home/home_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/classes/class_list_screen.dart';
import '../features/classes/roster_screen.dart';

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
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);