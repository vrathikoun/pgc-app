import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:pgc_app/providers/auth_provider.dart';
import 'package:pgc_app/screens/auth/login_screen.dart';
import 'package:pgc_app/screens/auth/register_screen.dart';
import 'package:pgc_app/screens/courses/course_list_screen.dart';
import 'package:pgc_app/screens/courses/course_detail_screen.dart';
import 'package:pgc_app/screens/bookings/my_bookings_screen.dart';
import 'package:pgc_app/screens/profile/profile_screen.dart';
import 'package:pgc_app/screens/admin/admin_dashboard_screen.dart';
import 'package:pgc_app/screens/admin/course_form_screen.dart';
import 'package:pgc_app/screens/admin/member_admin_screen.dart';
import 'package:pgc_app/screens/admin/schedule_admin_screen.dart';
import 'package:pgc_app/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);

  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider()..tryAutoLogin(),
      child: const PgcApp(),
    ),
  );
}

class PgcApp extends StatelessWidget {
  const PgcApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    final router = GoRouter(
      initialLocation: auth.isAuthenticated ? '/courses' : '/login',
      redirect: (context, state) {
        final loggedIn = auth.isAuthenticated;
        final location = state.matchedLocation;
        final onAuth = location == '/login' || location == '/register';
        final onAdmin = location.startsWith('/admin');

        if (!loggedIn && !onAuth) return '/login';
        if (loggedIn && onAuth) return '/courses';
        if (loggedIn && onAdmin && !(auth.member?.isAdmin ?? false)) {
          return '/courses';
        }

        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
        ShellRoute(
          builder: (context, state, child) => MainShell(child: child),
          routes: [
            GoRoute(path: '/courses', builder: (_, __) => const CourseListScreen()),
            GoRoute(
              path: '/courses/:id',
              builder: (_, state) => CourseDetailScreen(
                courseId: int.parse(state.pathParameters['id']!),
              ),
            ),
            GoRoute(path: '/bookings', builder: (_, __) => const MyBookingsScreen()),
            GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
            GoRoute(path: '/admin', builder: (_, __) => const AdminDashboardScreen()),
            GoRoute(path: '/admin/courses/new', builder: (_, __) => const CourseFormScreen()),
            GoRoute(path: '/admin/schedule', builder: (_, __) => const ScheduleAdminScreen()),
            GoRoute(path: '/admin/members', builder: (_, __) => const MemberAdminScreen()),
          ],
        ),
      ],
    );

    return MaterialApp.router(
      title: 'PGC App',
      debugShowCheckedModeBanner: false,
      theme: PgcTheme.dark(),
      routerConfig: router,
    );
  }
}

class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  int _selectedIndex(BuildContext context, bool isAdmin) {
    final location = GoRouterState.of(context).matchedLocation;

    if (location.startsWith('/courses')) return 0;
    if (location.startsWith('/bookings')) return 1;
    if (location.startsWith('/profile')) return 2;
    if (isAdmin && location.startsWith('/admin')) return 3;

    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthProvider>().member?.isAdmin ?? false;
    final index = _selectedIndex(context, isAdmin);

    final items = <_NavItem>[
      _NavItem(Icons.calendar_today, 'Planning', '/courses'),
      _NavItem(Icons.bookmark, 'Mes cours', '/bookings'),
      _NavItem(Icons.person, 'Profil', '/profile'),
      if (isAdmin) _NavItem(Icons.admin_panel_settings, 'Admin', '/admin'),
    ];

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface.withOpacity(0.96),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (i) {
            final selected = i == index;
            final item = items[i];

            return GestureDetector(
              onTap: () => context.go(item.route),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? AppColors.surface2 : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  item.icon,
                  color: selected ? AppColors.gold : AppColors.muted,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String route;

  _NavItem(this.icon, this.label, this.route);
}