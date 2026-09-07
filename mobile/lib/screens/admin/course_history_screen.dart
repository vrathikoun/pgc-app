import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:pgc_app/models/course.dart';
import 'package:pgc_app/providers/auth_provider.dart';
import 'package:pgc_app/theme/app_theme.dart';

/// Historique des cours passés (admin) : la fiche d'un cours passé montre la
/// liste des inscrits avec le badge « Présent » (pointage au scan QR).
class CourseHistoryScreen extends StatefulWidget {
  const CourseHistoryScreen({super.key});

  @override
  State<CourseHistoryScreen> createState() => _CourseHistoryScreenState();
}

class _CourseHistoryScreenState extends State<CourseHistoryScreen> {
  List<Course>? _courses;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = context.read<AuthProvider>().api;
      final now = DateTime.now();
      final courses = await api.getCourses(
        fromDate: now.subtract(const Duration(days: 60)),
        toDate: now,
      );
      courses.sort((a, b) => b.startTime.compareTo(a.startTime));
      if (!mounted) return;
      setState(() => _courses = courses);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayFmt = DateFormat('EEEE d MMMM', 'fr_FR');
    final timeFmt = DateFormat('HH:mm');

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.text),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/admin'),
        ),
        title: const Text('Historique des cours',
            style: TextStyle(color: AppColors.text)),
      ),
      body: _error != null
          ? Center(
              child: Text(_error!,
                  style: const TextStyle(color: AppColors.danger)))
          : _courses == null
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.gold))
              : _courses!.isEmpty
                  ? const Center(
                      child: Text('Aucun cours sur les 60 derniers jours',
                          style: TextStyle(color: AppColors.muted)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(22, 8, 22, 40),
                      itemCount: _courses!.length,
                      itemBuilder: (context, i) {
                        final c = _courses![i];
                        final local = c.startTime.toLocal();
                        final showHeader = i == 0 ||
                            !_sameDay(local, _courses![i - 1].startTime.toLocal());
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showHeader)
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: 18, bottom: 8),
                                child: Text(
                                  dayFmt.format(local).toUpperCase(),
                                  style: const TextStyle(
                                      color: AppColors.gold,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8),
                                ),
                              ),
                            InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => context.push('/courses/${c.id}'),
                              child: Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    Text(timeFmt.format(local),
                                        style: const TextStyle(
                                            color: AppColors.gold,
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(c.name,
                                          style: const TextStyle(
                                              color: AppColors.text,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                    const Icon(Icons.chevron_right,
                                        color: AppColors.muted, size: 20),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
