import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:pgc_app/models/course.dart';
import 'package:pgc_app/models/member.dart';
import 'package:pgc_app/providers/auth_provider.dart';
import 'package:pgc_app/theme/app_theme.dart';
import 'package:pgc_app/widgets/pgc_avatar.dart';

class CoachProfileScreen extends StatefulWidget {
  final int coachId;
  const CoachProfileScreen({super.key, required this.coachId});

  @override
  State<CoachProfileScreen> createState() => _CoachProfileScreenState();
}

class _CoachProfileScreenState extends State<CoachProfileScreen> {
  Member? _coach;
  List<Course> _courses = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = context.read<AuthProvider>().api;
      final coach = await api.getCoach(widget.coachId);
      final courses = await api.getCourses(coachId: widget.coachId);
      setState(() {
        _coach = coach;
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

  List<Course> get _uniqueCourseTypes {
    final seen = <String>{};
    final result = <Course>[];
    for (final c in _courses) {
      final key = '${c.name}|${c.courseType}|${c.level}';
      if (!seen.contains(key)) {
        seen.add(key);
        result.add(c);
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.gold)),
      );
    }

    if (_error != null || _coach == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.text),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/courses');
              }
            },
          ),
          title: const Text(
            'Détail du cours',
            style: TextStyle(color: AppColors.text),
          ),
        ),
        body: Center(
          child: Text(_error ?? 'Coach introuvable', style: const TextStyle(color: AppColors.danger)),
        ),
      );
    }

    final coach = _coach!;
    final initials = '${coach.firstName.isNotEmpty ? coach.firstName[0] : ''}${coach.lastName.isNotEmpty ? coach.lastName[0] : ''}';

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Profil coach')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 110),
          children: [
            Center(
              child: PgcAvatar(
                avatarUrl: coach.avatarUrl,
                initials: initials,
                radius: 58,
                showBorder: true,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              coach.fullName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 32,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _subtitle(coach),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 14),
            ),
            const SizedBox(height: 28),
            const Text(
              'Cours enseignés',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            if (_uniqueCourseTypes.isEmpty)
              _EmptyCoachCard(coachName: coach.firstName)
            else
              ..._uniqueCourseTypes.map((course) => _CourseTypeTile(course: course)),
          ],
        ),
      ),
    );
  }

  String _subtitle(Member coach) {
    final role = coach.role == 'admin' ? 'Admin / Coach' : 'Coach';
    final belt = coach.beltRank == null ? null : _beltLabel(coach.beltRank!);
    return belt == null ? role : '$role · $belt';
  }

  String _beltLabel(String belt) {
    const labels = {
      'white': 'Ceinture blanche',
      'blue': 'Ceinture bleue',
      'purple': 'Ceinture violette',
      'brown': 'Ceinture marron',
      'black': 'Ceinture noire',
    };
    return labels[belt] ?? belt;
  }
}

class _CourseTypeTile extends StatelessWidget {
  final Course course;
  const _CourseTypeTile({required this.course});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forCourseType(course.courseType);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withOpacity(0.22),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.sports_martial_arts, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.name,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${course.courseTypeLabel} · ${course.levelLabel}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCoachCard extends StatelessWidget {
  final String coachName;
  const _EmptyCoachCard({required this.coachName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        '$coachName n’a pas encore de cours assigné.',
        style: const TextStyle(color: AppColors.muted),
      ),
    );
  }
}
