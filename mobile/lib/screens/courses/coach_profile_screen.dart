import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
      final courses = await api.getCoursesByCoach(widget.coachId);

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
    final unique = <Course>[];

    for (final course in _courses) {
      final key = '${course.name.trim().toLowerCase()}|${course.courseType}|${course.level}';
      if (seen.add(key)) unique.add(course);
    }

    return unique;
  }

  String _initials(Member member) {
    final first = member.firstName.isNotEmpty ? member.firstName[0] : '';
    final last = member.lastName.isNotEmpty ? member.lastName[0] : '';
    final initials = '$first$last'.trim();
    return initials.isEmpty ? '?' : initials;
  }

  String _beltLabel(String? belt) {
    const labels = {
      'white': 'Ceinture blanche',
      'blue': 'Ceinture bleue',
      'purple': 'Ceinture violette',
      'brown': 'Ceinture marron',
      'black': 'Ceinture noire',
    };
    return labels[belt] ?? 'Niveau non renseigné';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Coach')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
                  ),
                )
              : _coach == null
                  ? const Center(
                      child: Text('Coach introuvable', style: TextStyle(color: AppColors.muted)),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(22, 18, 22, 110),
                        children: [
                          _Header(
                            coach: _coach!,
                            initials: _initials(_coach!),
                            apiBaseUrl: context.read<AuthProvider>().api.baseUrl,
                            beltLabel: _beltLabel(_coach!.beltRank),
                          ),
                          const SizedBox(height: 28),
                          const Text(
                            'Cours enseignés',
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_uniqueCourseTypes.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: const Text(
                                'Aucun cours assigné pour le moment.',
                                style: TextStyle(color: AppColors.muted),
                              ),
                            )
                          else
                            ..._uniqueCourseTypes.map((course) => _CourseTypeCard(course: course)),
                        ],
                      ),
                    ),
    );
  }
}

class _Header extends StatelessWidget {
  final Member coach;
  final String initials;
  final String apiBaseUrl;
  final String beltLabel;

  const _Header({
    required this.coach,
    required this.initials,
    required this.apiBaseUrl,
    required this.beltLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B5D3B), Color(0xFF041E16)],
        ),
        border: Border.all(color: AppColors.gold.withOpacity(0.20)),
      ),
      child: Column(
        children: [
          PgcAvatar(
            avatarUrl: coach.avatarUrl,
            initials: initials,
            apiBaseUrl: apiBaseUrl,
            radius: 58,
            showBorder: true,
          ),
          const SizedBox(height: 16),
          Text(
            coach.fullName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            coach.role == 'admin' ? 'Admin · Coach' : 'Coach',
            style: const TextStyle(
              color: AppColors.gold,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            beltLabel,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _CourseTypeCard extends StatelessWidget {
  final Course course;

  const _CourseTypeCard({required this.course});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
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
              color: AppColors.darkGreen,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.sports_mma, color: AppColors.gold),
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
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
