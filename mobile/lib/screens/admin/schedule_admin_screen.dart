import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:pgc_app/models/course.dart';
import 'package:pgc_app/providers/auth_provider.dart';
import 'package:pgc_app/theme/app_theme.dart';
import 'package:pgc_app/widgets/pgc_avatar.dart';
import 'package:pgc_app/widgets/pgc_section_header.dart';

class ScheduleAdminScreen extends StatefulWidget {
  const ScheduleAdminScreen({super.key});

  @override
  State<ScheduleAdminScreen> createState() => _ScheduleAdminScreenState();
}

class _ScheduleAdminScreenState extends State<ScheduleAdminScreen> {
  List<Course> _courses = [];
  bool _loading = true;
  String? _error;
  int? _deletingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final now = DateTime.now().subtract(const Duration(days: 1));

      final data = await context.read<AuthProvider>().api.getCourses(
            fromDate: now,
            toDate: now.add(const Duration(days: 365)),
          );

      if (!mounted) return;

      setState(() {
        _courses = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _delete(Course course) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text(
            'Supprimer le cours ?',
            style: TextStyle(color: AppColors.text),
          ),
          content: Text(
            'Cette action supprimera aussi les réservations associées à :\n\n${course.name}',
            style: const TextStyle(color: AppColors.muted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                'Supprimer',
                style: TextStyle(color: AppColors.danger),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() {
      _deletingId = course.id;
      _error = null;
    });

    try {
      await context.read<AuthProvider>().api.deleteCourse(course.id);

      if (!mounted) return;

      setState(() {
        _courses.removeWhere((c) => c.id == course.id);
        _deletingId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cours supprimé')),
      );

      await _load();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _deletingId = null;
        _error = e.toString();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Suppression impossible : $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('EEE d MMM', 'fr_FR');
    final tf = DateFormat('HH:mm');

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Planning admin'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.bg,
        onPressed: () => context.push('/admin/courses/new'),
        icon: const Icon(Icons.add),
        label: const Text('Cours'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const PgcSectionHeader(
              eyebrow: 'Schedule',
              title: 'Planning',
              subtitle: 'Modifier ou supprimer les cours créés.',
            ),
            const SizedBox(height: 20),

            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
              ),

            if (_error != null) ...[
              Text(
                _error!,
                style: const TextStyle(color: AppColors.danger),
              ),
              const SizedBox(height: 12),
            ],

            if (!_loading && _courses.isEmpty)
              const Text(
                'Aucun cours.',
                style: TextStyle(color: AppColors.muted),
              ),

            if (!_loading)
              ..._courses.map(
                (course) {
                  final isDeleting = _deletingId == course.id;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: AppColors.gold.withOpacity(.12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 68,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.green,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            children: [
                              Text(
                                DateFormat('d').format(course.startTime),
                                style: const TextStyle(
                                  color: AppColors.gold,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                DateFormat('MMM', 'fr_FR')
                                    .format(course.startTime)
                                    .toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.text,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
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
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${df.format(course.startTime)} · ${tf.format(course.startTime)}-${tf.format(course.endTime)}',
                                style: const TextStyle(color: AppColors.muted),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  PgcAvatar(
                                    avatarUrl: course.effectiveCoachAvatarUrl,
                                    initials: course.coachInitials,
                                    radius: 13,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${course.coachFullName} · ${course.levelLabel} · ${course.spotsAvailable ?? course.maxCapacity}/${course.maxCapacity} places',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Modifier',
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: AppColors.gold,
                          ),
                          onPressed: isDeleting
                              ? null
                              : () => context.push(
                                    '/admin/courses/${course.id}/edit',
                                  ),
                        ),
                        IconButton(
                          tooltip: 'Supprimer',
                          icon: isDeleting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.danger,
                                  ),
                                )
                              : const Icon(
                                  Icons.delete_outline,
                                  color: AppColors.danger,
                                ),
                          onPressed: _deletingId == null
                              ? () => _delete(course)
                              : null,
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}