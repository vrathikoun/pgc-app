import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pgc_app/models/course.dart';
import 'package:pgc_app/providers/auth_provider.dart';

class CourseListScreen extends StatefulWidget {
  const CourseListScreen({super.key});

  @override
  State<CourseListScreen> createState() => _CourseListScreenState();
}

class _CourseListScreenState extends State<CourseListScreen> {
  List<Course> _courses = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    final api = context.read<AuthProvider>().api;
    try {
      final now = DateTime.now();
      final courses = await api.getCourses(
        fromDate: now,
        toDate: now.add(const Duration(days: 14)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Planning', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() => _loading = true);
              _loadCourses();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _courses.isEmpty
                  ? const Center(
                      child: Text(
                        'Aucun cours prévu',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadCourses,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _courses.length,
                        itemBuilder: (context, i) => _CourseCard(
                          course: _courses[i],
                          onTap: () => context.go('/courses/${_courses[i].id}'),
                        ),
                      ),
                    ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final Course course;
  final VoidCallback onTap;

  const _CourseCard({required this.course, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEE d MMM', 'fr_FR');
    final timeFormat = DateFormat('HH:mm');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: course.isFull ? Colors.grey.withOpacity(0.3) : Colors.redAccent.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            // Date
            Container(
              width: 56,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(
                    DateFormat('d').format(course.startTime),
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    DateFormat('MMM', 'fr_FR').format(course.startTime),
                    style: TextStyle(color: Colors.grey[400], fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${course.courseTypeLabel} · ${course.levelLabel}',
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${timeFormat.format(course.startTime)} → ${timeFormat.format(course.endTime)}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ),
            // Places
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  course.isFull ? 'Complet' : '${course.spotsAvailable} places',
                  style: TextStyle(
                    color: course.isFull ? Colors.grey : Colors.greenAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }
}