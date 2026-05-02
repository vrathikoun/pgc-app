import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:pgc_app/models/course.dart';
import 'package:pgc_app/models/member.dart';
import 'package:pgc_app/providers/auth_provider.dart';
import 'package:pgc_app/theme/app_theme.dart';

class CourseListScreen extends StatefulWidget {
  const CourseListScreen({super.key});

  @override
  State<CourseListScreen> createState() => _CourseListScreenState();
}

class _CourseListScreenState extends State<CourseListScreen> {
  List<Course> _courses = [];
  List<Member> _coaches = [];
  bool _loading = true;
  String? _error;
  int _selectedDayIndex = 0;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  List<DateTime> get _days =>
      List.generate(7, (i) => _today.add(Duration(days: i)));

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = context.read<AuthProvider>().api;

      final courses = await api.getCourses(
        fromDate: _today,
        toDate: _today.add(const Duration(days: 7)),
      );

      final members = await api.getMembers();

      final coaches = members
          .where((m) => m.role == 'coach' || m.role == 'admin')
          .toList();

      for (final coach in coaches) {
        debugPrint('COACH ${coach.firstName} avatar=${coach.avatarUrl}');
      }

      setState(() {
        _courses = courses;
        _coaches = coaches;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Course> get _selectedCourses {
    final day = _days[_selectedDayIndex];

    return _courses.where((course) {
      final date = course.startTime;
      return date.year == day.year &&
          date.month == day.month &&
          date.day == day.day;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final selectedCourses = _selectedCourses;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
            children: [
              _TopBar(onRefresh: _loadData),
              const SizedBox(height: 28),
              const Text(
                'Polo Grappling Club',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 24),
              const _SectionTitle('Coachs du moment'),
              const SizedBox(height: 12),
              _CoachStrip(coaches: _coaches),
              const SizedBox(height: 28),
              const _SectionTitle('Planning 7 jours'),
              const SizedBox(height: 12),
              _DaySelector(
                days: _days,
                selectedIndex: _selectedDayIndex,
                onSelected: (i) => setState(() => _selectedDayIndex = i),
              ),
              const SizedBox(height: 20),
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: AppColors.gold),
                  ),
                )
              else if (_error != null)
                Text(_error!, style: const TextStyle(color: AppColors.danger))
              else if (selectedCourses.isEmpty)
                const _EmptyState()
              else
                ...selectedCourses.map(
                  (course) => _CourseCard(course: course),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onRefresh;

  const _TopBar({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipOval(
          child: Image.asset(
            'assets/images/pgc_logo.png',
            width: 42,
            height: 42,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  'PGC',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'PGC',
          style: TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: onRefresh,
          child: Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: AppColors.green,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.refresh, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _CoachStrip extends StatelessWidget {
  final List<Member> coaches;

  const _CoachStrip({required this.coaches});

  ImageProvider _avatar(String? url) {
    final cleanUrl = url?.trim();

    if (cleanUrl == null || cleanUrl.isEmpty) {
      return const AssetImage('assets/images/default_avatar.png');
    }

    if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')) {
      return NetworkImage(cleanUrl);
    }

    return AssetImage(cleanUrl);
  }

  @override
  Widget build(BuildContext context) {
    if (coaches.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Aucun coach configuré',
            style: TextStyle(color: AppColors.muted),
          ),
        ),
      );
    }

    return SizedBox(
      height: 106,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: coaches.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (_, i) {
          final coach = coaches[i];

          return SizedBox(
            width: 84,
            child: Column(
              children: [
                ClipOval(
                  child: Image(
                    image: _avatar(coach.avatarUrl),
                    width: 68,
                    height: 68,
                    fit: BoxFit.cover,
                    errorBuilder: (_, error, __) {
                      debugPrint(
                        'AVATAR ERROR ${coach.firstName}: ${coach.avatarUrl} / $error',
                      );

                      return Image.asset(
                        'assets/images/default_avatar.png',
                        width: 68,
                        height: 68,
                        fit: BoxFit.cover,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  coach.firstName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DaySelector extends StatelessWidget {
  final List<DateTime> days;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _DaySelector({
    required this.days,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 70,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final day = days[i];
          final selected = i == selectedIndex;

          return GestureDetector(
            onTap: () => onSelected(i),
            child: Container(
              width: 60,
              decoration: BoxDecoration(
                color: selected ? AppColors.gold : AppColors.surface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E', 'fr_FR').format(day).replaceAll('.', ''),
                    style: TextStyle(
                      color: selected ? Colors.black : AppColors.muted,
                    ),
                  ),
                  Text(
                    DateFormat('d').format(day),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: selected ? Colors.black : AppColors.text,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final Course course;

  const _CourseCard({required this.course});

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(course.startTime);

    return GestureDetector(
      onTap: () => context.go('/courses/${course.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF0B5D3B),
              Color(0xFF042D1F),
            ],
          ),
        ),
        child: Row(
          children: [
            Text(
              time,
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                course.name,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.text,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: const TextStyle(color: AppColors.muted)),
        const SizedBox(width: 10),
        Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Aucun cours',
      style: TextStyle(color: AppColors.muted),
    );
  }
}