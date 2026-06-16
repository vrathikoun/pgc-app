import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:pgc_app/models/course.dart';
import 'package:pgc_app/providers/auth_provider.dart';
import 'package:pgc_app/services/api_service.dart';
import 'package:pgc_app/theme/app_theme.dart';
import 'package:pgc_app/widgets/pgc_avatar.dart';

class CourseDetailScreen extends StatefulWidget {
  final int courseId;
  const CourseDetailScreen({super.key, required this.courseId});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  Course? _course;
  bool _loading = true;
  bool _booking = false;
  String? _error;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _loadCourse();
  }

  Future<void> _loadCourse() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final course = await context.read<AuthProvider>().api.getCourse(widget.courseId);
      setState(() {
        _course = course;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _book() async {
    setState(() => _booking = true);
    try {
      final booking = await context.read<AuthProvider>().api.createBooking(widget.courseId);
      setState(() {
        _successMessage = booking.isWaitlist
            ? 'Cours complet — tu es n°${booking.waitlistPosition ?? '?'} en liste d’attente ⏳'
            : 'Réservation confirmée ✅';
      });
      await _loadCourse();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
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
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _course == null
              ? Center(child: Text(_error ?? 'Cours introuvable', style: const TextStyle(color: AppColors.danger)))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final course = _course!;
    final dateFormat = DateFormat('EEEE d MMMM yyyy', 'fr_FR');
    final timeFormat = DateFormat('HH:mm');

    return RefreshIndicator(
      onRefresh: _loadCourse,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 110),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0B5D3B), Color(0xFF042D1F)]),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(course.courseTypeLabel, style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                Text(course.name, style: const TextStyle(color: AppColors.text, fontSize: 34, fontWeight: FontWeight.w900, height: 1)),
                if (course.description != null && course.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(course.description!, style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.4)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (course.coachId != null) _CoachCard(course: course),
          const SizedBox(height: 18),
          _InfoCard(
            children: [
              _InfoRow(Icons.calendar_month, dateFormat.format(course.startTime)),
              _InfoRow(Icons.schedule, '${timeFormat.format(course.startTime)} → ${timeFormat.format(course.endTime)}'),
              _InfoRow(Icons.signal_cellular_alt, course.levelLabel),
              _InfoRow(Icons.group, '${course.spotsAvailable ?? '-'} places restantes / ${course.maxCapacity}'),
            ],
          ),
          const SizedBox(height: 18),
          if (_successMessage != null)
            _MessageBox(text: _successMessage!, color: AppColors.green)
          else if (_error != null)
            _MessageBox(text: _error!, color: AppColors.danger),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _booking ? null : _book,
              style: ElevatedButton.styleFrom(
                backgroundColor: course.isFull ? AppColors.surface2 : AppColors.darkGreen,
                foregroundColor: AppColors.text,
              ),
              child: _booking
                  ? const CircularProgressIndicator(color: AppColors.text)
                  : Text(course.isFull ? 'Rejoindre la liste d’attente' : 'Réserver ce cours'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoachCard extends StatelessWidget {
  final Course course;
  const _CoachCard({required this.course});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/coaches/${course.coachId}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            PgcAvatar(avatarUrl: course.coachAvatarUrl, initials: course.coachInitials, radius: 24, showBorder: true),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Coach', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                  const SizedBox(height: 3),
                  Text(course.coachFullName, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w900, fontSize: 16)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.gold),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(children: children),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow(this.icon, this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: AppColors.gold, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: const TextStyle(color: AppColors.text, fontSize: 15))),
          ],
        ),
      );
}

class _MessageBox extends StatelessWidget {
  final String text;
  final Color color;
  const _MessageBox({required this.text, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
      );
}
