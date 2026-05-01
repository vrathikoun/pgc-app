import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pgc_app/models/course.dart';
import 'package:pgc_app/providers/auth_provider.dart';
import 'package:pgc_app/theme/app_theme.dart';
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
      final now = DateTime.now().subtract(const Duration(days: 1));
      final data = await context.read<AuthProvider>().api.getCourses(
            fromDate: now,
            toDate: now.add(const Duration(days: 45)),
          );
      setState(() => _courses = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(Course c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer le cours ?'),
        content: Text(c.name),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true) return;
    await context.read<AuthProvider>().api.deleteCourse(c.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('EEE d MMM', 'fr_FR');
    final tf = DateFormat('HH:mm');

    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.bg,
        onPressed: () => context.go('/admin/courses/new'),
        icon: const Icon(Icons.add),
        label: const Text('Cours'),
      ),
      appBar: AppBar(title: const Text('Planning admin')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const PgcSectionHeader(
              eyebrow: 'Schedule',
              title: 'Planning',
              subtitle: 'Vue admin des cours à venir.',
            ),
            const SizedBox(height: 20),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (_error != null) Text(_error!, style: const TextStyle(color: AppColors.danger)),
            if (!_loading)
              ..._courses.map(
                (c) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.gold.withOpacity(.12)),
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
                            Text(DateFormat('d').format(c.startTime), style: const TextStyle(color: AppColors.gold, fontSize: 22, fontWeight: FontWeight.w900)),
                            Text(DateFormat('MMM', 'fr_FR').format(c.startTime).toUpperCase(), style: const TextStyle(color: AppColors.text, fontSize: 10)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text('${df.format(c.startTime)} · ${tf.format(c.startTime)}-${tf.format(c.endTime)}', style: const TextStyle(color: AppColors.muted)),
                            Text('${c.levelLabel} · ${c.spotsAvailable ?? c.maxCapacity}/${c.maxCapacity} places', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.danger), onPressed: () => _delete(c)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
