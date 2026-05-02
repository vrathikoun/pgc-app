import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:pgc_app/models/course.dart';
import 'package:pgc_app/providers/auth_provider.dart';
import 'package:pgc_app/theme/app_theme.dart';

/// Vue "Schedule" : lundi → dimanche en colonnes, tous les cours visibles.
/// Pensée pour être scalable : chaque colonne est indépendante,
/// les couleurs viennent de AppColors.forCourseType().
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  List<Course> _courses = [];
  bool _loading = true;
  String? _error;

  // Lundi de la semaine affichée
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    _weekStart = _mondayOf(DateTime.now());
    _load();
  }

  DateTime _mondayOf(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  List<DateTime> get _weekDays =>
      List.generate(7, (i) => _weekStart.add(Duration(days: i)));

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<AuthProvider>().api;
      final courses = await api.getCourses(
        fromDate: _weekStart,
        toDate: _weekStart.add(const Duration(days: 7)),
      );
      setState(() {
        _courses = courses;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Course> _coursesForDay(DateTime day) => _courses.where((c) {
        final d = c.startTime;
        return d.year == day.year &&
            d.month == day.month &&
            d.day == day.day;
      }).toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));

  void _prevWeek() {
    setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7)));
    _load();
  }

  void _nextWeek() {
    setState(() => _weekStart = _weekStart.add(const Duration(days: 7)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _WeekHeader(
              weekStart: _weekStart,
              onPrev: _prevWeek,
              onNext: _nextWeek,
              onToday: () {
                setState(() => _weekStart = _mondayOf(DateTime.now()));
                _load();
              },
            ),
            const SizedBox(height: 8),
            _DayHeaders(days: _weekDays),
            const Divider(color: AppColors.border, height: 1),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.gold),
                    )
                  : _error != null
                      ? Center(
                          child: Text(_error!,
                              style:
                                  const TextStyle(color: AppColors.danger)),
                        )
                      : _ScheduleGrid(
                          days: _weekDays,
                          coursesFor: _coursesForDay,
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── En-tête semaine ───────────────────────────────────────────────────────────

class _WeekHeader extends StatelessWidget {
  final DateTime weekStart;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;

  const _WeekHeader({
    required this.weekStart,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  @override
  Widget build(BuildContext context) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    final fmt = DateFormat('d MMM', 'fr_FR');
    final label = '${fmt.format(weekStart)} – ${fmt.format(weekEnd)}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left, color: AppColors.text),
          ),
          Expanded(
            child: Column(
              children: [
                const Text(
                  'Planning semaine',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onToday,
            child: const Text(
              'Auj.',
              style: TextStyle(color: AppColors.gold, fontSize: 13),
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right, color: AppColors.text),
          ),
        ],
      ),
    );
  }
}

// ── En-têtes des jours ────────────────────────────────────────────────────────

class _DayHeaders extends StatelessWidget {
  final List<DateTime> days;

  const _DayHeaders({required this.days});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: days.map((day) {
          final isToday = day.year == today.year &&
              day.month == today.month &&
              day.day == today.day;

          return Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: isToday
                  ? BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppColors.gold, width: 2),
                      ),
                    )
                  : null,
              child: Column(
                children: [
                  Text(
                    DateFormat('E', 'fr_FR')
                        .format(day)
                        .replaceAll('.', '')
                        .toUpperCase(),
                    style: TextStyle(
                      color: isToday ? AppColors.gold : AppColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('d').format(day),
                    style: TextStyle(
                      color: isToday ? AppColors.gold : AppColors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Grille principale ─────────────────────────────────────────────────────────

class _ScheduleGrid extends StatelessWidget {
  final List<DateTime> days;
  final List<Course> Function(DateTime) coursesFor;

  const _ScheduleGrid({
    required this.days,
    required this.coursesFor,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 80),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: days
            .map((day) => Expanded(
                  child: _DayColumn(
                    day: day,
                    courses: coursesFor(day),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

// ── Colonne d'un jour ─────────────────────────────────────────────────────────

class _DayColumn extends StatelessWidget {
  final DateTime day;
  final List<Course> courses;

  const _DayColumn({required this.day, required this.courses});

  @override
  Widget build(BuildContext context) {
    if (courses.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: SizedBox(height: 40),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        children: courses
            .map((c) => _ScheduleCourseChip(course: c))
            .toList(),
      ),
    );
  }
}

// ── Chip d'un cours dans la grille ────────────────────────────────────────────

class _ScheduleCourseChip extends StatelessWidget {
  final Course course;

  const _ScheduleCourseChip({required this.course});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forCourseType(course.courseType);
    final time = DateFormat('HH:mm').format(course.startTime);

    return GestureDetector(
      onTap: () => context.go('/courses/${course.id}'),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              time,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              course.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
            if (!course.isFull) ...[
              const SizedBox(height: 2),
              Text(
                '${course.spotsAvailable}p',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 9,
                ),
              ),
            ] else
              const Text(
                'Complet',
                style: TextStyle(color: Colors.red, fontSize: 9),
              ),
          ],
        ),
      ),
    );
  }
}