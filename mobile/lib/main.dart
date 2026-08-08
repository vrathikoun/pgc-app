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
import 'package:pgc_app/screens/auth/forgot_password_screen.dart';
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
        final onAuth = location == '/login' ||
            location == '/register' ||
            location == '/forgot-password';
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

        GoRoute(
          path: '/forgot-password',
          builder: (_, __) => const ForgotPasswordScreen(),
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

    // Onglets latéraux (la carte QR est un bouton central mis en avant, à part).
    final sideTabs = <_NavItem>[
      _NavItem(Icons.fitness_center, 'Cours', '/courses'),
      _NavItem(Icons.calendar_today, 'Planning', '/schedule'),
      _NavItem(Icons.bookmark, 'Résas', '/bookings'),
      _NavItem(Icons.person, 'Profil', '/profile'),
      if (hasAcademyAccess) _NavItem(Icons.school, 'Academy', '/academy'),
      if (isAdmin) _NavItem(Icons.admin_panel_settings, 'Admin', '/admin'),
    ];

    final location = GoRouterState.of(context).matchedLocation;

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
        bottomNavigationBar: _BottomBar(sideTabs: sideTabs, location: location),
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

/// Barre du bas avec un bouton central « Ma carte » (QR) mis en avant :
/// gros cercle doré qui ressort au-dessus de la barre.
class _BottomBar extends StatelessWidget {
  final List<_NavItem> sideTabs;
  final String location;
  const _BottomBar({required this.sideTabs, required this.location});

  @override
  Widget build(BuildContext context) {
    // Répartit les onglets à gauche et à droite du bouton central.
    final mid = (sideTabs.length / 2).ceil();
    final left = sideTabs.sublist(0, mid);
    final right = sideTabs.sublist(mid);
    final cardActive = location.startsWith('/access/card');

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        height: 66,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            for (final t in left) Expanded(child: _sideItem(context, t)),
            _CenterCardButton(
              active: cardActive,
              onTap: () => context.go('/access/card'),
            ),
            for (final t in right) Expanded(child: _sideItem(context, t)),
          ],
        ),
      ),
    );
  }

  Widget _sideItem(BuildContext context, _NavItem t) {
    final active = location.startsWith(t.route);
    final color = active ? AppColors.gold : AppColors.muted;
    return InkWell(
      onTap: () => context.go(t.route),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(t.icon, color: color, size: 24),
          const SizedBox(height: 3),
          Text(t.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 10)),
        ],
      ),
    );
  }
}

class _CenterCardButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _CenterCardButton({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 74,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform.translate(
              offset: const Offset(0, -14), // ressort au-dessus de la barre
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? AppColors.gold : AppColors.darkGreen,
                  border: Border.all(color: AppColors.bg, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.35),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Icon(Icons.qr_code_2,
                    color: active ? AppColors.bg : AppColors.text, size: 30),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -14),
              child: Text('Ma carte',
                  style: TextStyle(
                      color: active ? AppColors.gold : AppColors.text,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}