import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:pgc_app/screens/academy/academy_screen.dart';
import 'package:pgc_app/screens/academy/academy_section_screen.dart';

import 'package:pgc_app/providers/auth_provider.dart';
import 'package:pgc_app/services/push_notification_service.dart';
import 'package:pgc_app/screens/auth/login_screen.dart';
import 'package:pgc_app/screens/auth/register_screen.dart';
import 'package:pgc_app/screens/courses/course_list_screen.dart';
import 'package:pgc_app/screens/courses/course_detail_screen.dart';
import 'package:pgc_app/screens/courses/schedule_screen.dart';
import 'package:pgc_app/screens/coaches/coach_profile_screen.dart';
import 'package:pgc_app/screens/bookings/my_bookings_screen.dart';
import 'package:pgc_app/screens/profile/profile_screen.dart';
import 'package:pgc_app/screens/access/access_card_screen.dart';
import 'package:pgc_app/screens/access/access_scanner_screen.dart';
import 'package:pgc_app/screens/admin/admin_dashboard_screen.dart';
import 'package:pgc_app/screens/admin/course_form_screen.dart';
import 'package:pgc_app/screens/admin/member_admin_screen.dart';
import 'package:pgc_app/screens/admin/member_profile_admin_screen.dart';
import 'package:pgc_app/screens/admin/academy_admin_screen.dart';
import 'package:pgc_app/screens/admin/schedule_admin_screen.dart';
import 'package:pgc_app/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);
  await PushNotificationService.initApp();

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
        GoRoute(
          path: '/',
          redirect: (_, __) => '/courses',
        ),

        GoRoute(
          path: '/login',
          builder: (_, __) => const LoginScreen(),
        ),

        GoRoute(
          path: '/register',
          builder: (_, __) => const RegisterScreen(),
        ),

        ShellRoute(
          builder: (context, state, child) => MainShell(child: child),
          routes: [
            GoRoute(
              path: '/courses',
              builder: (_, __) => const CourseListScreen(),
            ),

            GoRoute(
              path: '/schedule',
              builder: (_, __) => const ScheduleScreen(),
            ),

            GoRoute(
              path: '/courses/:id',
              builder: (_, state) => CourseDetailScreen(
                courseId: int.parse(state.pathParameters['id']!),
              ),
            ),

            GoRoute(
              path: '/bookings',
              builder: (_, __) => const MyBookingsScreen(),
            ),

            GoRoute(
              path: '/',
              redirect: (_, __) => '/courses',
            ),

            GoRoute(
              path: '/academy',
              builder: (_, __) => const AcademyScreen(),
            ),

            GoRoute(
              path: '/academy/:section',
              builder: (_, state) => AcademySectionScreen(
                section: Uri.decodeComponent(state.pathParameters['section']!),
                videos: state.extra is List ? List.from(state.extra as List) : [],
              ),
            ),

            GoRoute(
              path: '/profile',
              builder: (_, __) => const ProfileScreen(),
            ),

            GoRoute(
              path: '/access/card',
              builder: (_, __) => const AccessCardScreen(),
            ),

            GoRoute(
              path: '/access/scan',
              builder: (_, __) => const AccessScannerScreen(),
            ),

            GoRoute(
              path: '/coaches/:id',
              builder: (_, state) => CoachProfileScreen(
                coachId: int.parse(state.pathParameters['id']!),
              ),
            ),

            // ADMIN
            GoRoute(
              path: '/admin',
              builder: (_, __) => const AdminDashboardScreen(),
            ),

            GoRoute(
              path: '/admin/courses/new',
              builder: (_, __) => const CourseFormScreen(),
            ),

            GoRoute(
              path: '/admin/courses/:id/edit',
              builder: (_, state) => CourseFormScreen(
                courseId: int.parse(state.pathParameters['id']!),
              ),
            ),

            GoRoute(
              path: '/admin/schedule',
              builder: (_, __) => const ScheduleAdminScreen(),
            ),

            GoRoute(
              path: '/admin/members',
              builder: (_, __) => const MemberAdminScreen(),
            ),

            GoRoute(
              path: '/admin/members/:id',
              builder: (_, state) => MemberProfileAdminScreen(
                memberId: int.parse(state.pathParameters['id']!),
              ),
            ),

            GoRoute(
              path: '/admin/academy',
              builder: (_, __) => const AcademyAdminScreen(),
            ),
          ],
        ),
      ],
    );

    return MaterialApp.router(
      title: 'Polo Grappling Club',
      debugShowCheckedModeBanner: false,
      theme: PgcTheme.dark(),
      routerConfig: router,
    );
  }
}

class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthProvider>().member?.isAdmin ?? false;
    final hasAcademyAccess = context.watch<AuthProvider>().member?.subscriptionPlan == 'unlimited';

    // Onglets et routes construits ensemble : les index restent alignés même
    // quand Academy ou Admin sont masqués.
    final tabs = <_NavItem>[
      _NavItem(Icons.fitness_center, 'Courses', '/courses'),
      _NavItem(Icons.calendar_today, 'Schedule', '/schedule'),
      _NavItem(Icons.bookmark, 'Bookings', '/bookings'),
      _NavItem(Icons.person, 'Profile', '/profile'),
      if (hasAcademyAccess) _NavItem(Icons.school, 'Academy', '/academy'),
      if (isAdmin) _NavItem(Icons.admin_panel_settings, 'Admin', '/admin'),
    ];

    final location = GoRouterState.of(context).matchedLocation;
    var selectedIndex = tabs.indexWhere((t) => location.startsWith(t.route));
    if (selectedIndex < 0) selectedIndex = 0;

    return PopScope(
      // On intercepte toujours le retour système (bouton/geste Android) :
      // 1. un écran est empilé → on dépile ;
      // 2. on est sur un onglet ≠ accueil → retour à l'accueil ;
      // 3. on est sur l'accueil → on laisse l'app se fermer.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final router = GoRouter.of(context);
        if (router.canPop()) {
          router.pop();
        } else if (GoRouterState.of(context).matchedLocation != '/courses') {
          context.go('/courses');
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: child,
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BottomNavigationBar(
                backgroundColor: AppColors.surface,
                selectedItemColor: AppColors.gold,
                unselectedItemColor: AppColors.muted,
                type: BottomNavigationBarType.fixed,
                currentIndex: selectedIndex,
                onTap: (i) => context.go(tabs[i].route),
                items: [
                  for (final tab in tabs)
                    BottomNavigationBarItem(icon: Icon(tab.icon), label: tab.label),
                ],
              ),
            ),
          ),
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