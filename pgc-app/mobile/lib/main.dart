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

        if (!loggedIn && !onAuth) {
          return '/login';
        }

        if (loggedIn && onAuth) {
          return '/courses';
        }

        return null;
      },
      routes: [
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
              path: '/profile',
              builder: (_, __) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    );

    return MaterialApp.router(
      title: 'PGC App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: Colors.redAccent,
          secondary: Colors.redAccent,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
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

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    if (location.startsWith('/courses')) return 0;
    if (location.startsWith('/bookings')) return 1;
    if (location.startsWith('/profile')) return 2;

    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF1A1A1A),
        selectedItemColor: Colors.redAccent,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex(context),
        onTap: (i) {
          switch (i) {
            case 0:
              context.go('/courses');
              break;
            case 1:
              context.go('/bookings');
              break;
            case 2:
              context.go('/profile');
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Planning',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark),
            label: 'Mes cours',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}