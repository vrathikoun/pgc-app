import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pgc_app/models/course.dart';
import 'package:pgc_app/providers/auth_provider.dart';
import 'package:pgc_app/services/api_service.dart';

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
    final api = context.read<AuthProvider>().api;
    try {
      final courses = await api.getCourses();
      final course = courses.firstWhere((c) => c.id == widget.courseId);
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
    final api = context.read<AuthProvider>().api;
    try {
      final booking = await api.createBooking(widget.courseId);
      setState(() {
        _successMessage = booking.isWaitlist
            ? 'Cours complet — tu es en liste d\'attente ⏳'
            : 'Réservation confirmée ✅';
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/courses'),
        ),
        title: const Text('Détail du cours', style: TextStyle(color: Colors.white)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
          : _course == null
              ? const Center(child: Text('Cours introuvable', style: TextStyle(color: Colors.grey)))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final course = _course!;
    final dateFormat = DateFormat('EEEE d MMMM yyyy', 'fr_FR');
    final timeFormat = DateFormat('HH:mm');

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre
          Text(
            course.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            course.courseTypeLabel,
            style: const TextStyle(color: Colors.redAccent, fontSize: 16),
          ),
          const SizedBox(height: 24),

          // Infos
          _infoRow(Icons.calendar_today, dateFormat.format(course.startTime)),
          const SizedBox(height: 12),
          _infoRow(
            Icons.access_time,
            '${timeFormat.format(course.startTime)} → ${timeFormat.format(course.endTime)}',
          ),
          const SizedBox(height: 12),
          _infoRow(Icons.signal_cellular_alt, course.levelLabel),
          const SizedBox(height: 12),
          _infoRow(
            Icons.people,
            course.isFull
                ? 'Cours complet (liste d\'attente disponible)'
                : '${course.spotsAvailable} place(s) disponible(s)',
          ),

          if (course.description != null) ...[
            const SizedBox(height: 24),
            Text(
              'Description',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              course.description!,
              style: const TextStyle(color: Colors.white70),
            ),
          ],

          const Spacer(),

          // Messages
          if (_successMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _successMessage!,
                style: const TextStyle(color: Colors.greenAccent),
                textAlign: TextAlign.center,
              ),
            ),
          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 16),

          // Bouton réserver
          if (_successMessage == null)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _booking ? null : _book,
                style: ElevatedButton.styleFrom(
                  backgroundColor: course.isFull ? Colors.grey[700] : Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _booking
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        course.isFull ? 'Rejoindre la liste d\'attente' : 'Réserver ce cours',
                        style: const TextStyle(fontSize: 16, color: Colors.white),
                      ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.redAccent, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 15)),
        ),
      ],
    );
  }
}