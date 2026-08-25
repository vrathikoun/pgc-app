import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:pgc_app/models/booking.dart';
import 'package:pgc_app/models/course.dart';
import 'package:pgc_app/models/member.dart';
import 'package:pgc_app/providers/auth_provider.dart';
import 'package:pgc_app/services/api_service.dart';
import 'package:pgc_app/theme/app_theme.dart';
import 'package:pgc_app/utils/booking_window.dart';
import 'package:pgc_app/widgets/pgc_avatar.dart';

class CourseDetailScreen extends StatefulWidget {
  final int courseId;
  const CourseDetailScreen({super.key, required this.courseId});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  Course? _course;
  Booking? _myBooking; // réservation active (confirmée ou liste d'attente)
  List<CourseParticipant>? _participants; // visible coach du cours / admin
  bool _loading = true;
  bool _booking = false;
  bool _cancelling = false;
  String? _error;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _loadCourse();
  }

  Future<void> _loadCourse({bool silent = false}) async {
    // silent : rafraîchit les données sans blanchir l'écran (ex. après une
    // réservation, pour que le message de succès reste visible).
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final api = context.read<AuthProvider>().api;
      final course = await api.getCourse(widget.courseId);
      // Ma réservation éventuelle sur ce cours (pour adapter les boutons).
      Booking? mine;
      try {
        final bookings = await api.getMyBookings();
        for (final b in bookings) {
          if (b.courseId == widget.courseId && (b.isConfirmed || b.isWaitlist)) {
            mine = b;
            break;
          }
        }
      } catch (_) {}
      // Liste des inscrits : coach assigné au cours ou admin uniquement.
      List<CourseParticipant>? participants;
      final me = context.read<AuthProvider>().member;
      if (me != null && (me.isAdmin || (me.isCoach && course.coachId == me.id))) {
        try {
          participants = await api.getCourseBookings(widget.courseId);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _course = course;
        _myBooking = mine;
        _participants = participants;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (!silent) _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _book() async {
    setState(() {
      _booking = true;
      _error = null;
      _successMessage = null;
    });
    try {
      final booking = await context.read<AuthProvider>().api.createBooking(widget.courseId);
      if (!mounted) return;
      final message = booking.isWaitlist
          ? 'Cours complet — tu es n°${booking.waitlistPosition ?? '?'} en liste d’attente ⏳'
          : 'Réservation confirmée ✅';
      setState(() {
        _successMessage = message;
        _myBooking = booking;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: booking.isWaitlist ? AppColors.gold : AppColors.green,
          duration: const Duration(seconds: 3),
        ),
      );
      await _loadCourse(silent: true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
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

  /// Cours réservable si dans la fenêtre semaine N / N+1 (le backend revérifie).
  bool get _bookable =>
      _course != null && BookingWindow.isWithinWindow(_course!.startTime);

  Future<void> _confirmCancel() async {
    final course = _course!;
    final soon =
        course.startTime.difference(DateTime.now()) < const Duration(hours: 2);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Annuler ta réservation ?',
            style: TextStyle(color: AppColors.text)),
        content: Text(
          soon
              ? 'Le cours commence dans moins de 2 heures. Annuler si tard '
                  'pénalise le club et les membres en liste d’attente — '
                  'préviens ton coach si possible.'
              : 'Ta place sera libérée pour les membres en liste d’attente.',
          style: const TextStyle(color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Garder ma place',
                style: TextStyle(color: AppColors.text)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Me désinscrire',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _cancelling = true;
      _error = null;
      _successMessage = null;
    });
    try {
      await context.read<AuthProvider>().api.cancelBooking(_myBooking!.id);
      if (!mounted) return;
      setState(() => _myBooking = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Réservation annulée'),
          backgroundColor: AppColors.darkGreen,
        ),
      );
      await _loadCourse(silent: true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
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
          // Liste des inscrits — uniquement chargée pour le coach du cours/admin.
          if (_participants != null) ...[
            const SizedBox(height: 18),
            _ParticipantsCard(participants: _participants!),
          ],
          const SizedBox(height: 18),
          if (_error != null)
            _MessageBox(text: _error!, color: AppColors.danger)
          else if (_myBooking != null)
            _MessageBox(
              text: _successMessage ??
                  (_myBooking!.isWaitlist
                      ? 'Tu es en liste d’attente ⏳'
                      : 'Réservation confirmée ✅'),
              color: AppColors.green,
            )
          else if (!_bookable)
            const _MessageBox(
              text:
                  'Ce cours n’est pas encore réservable : seuls les cours de la semaine en cours et de la semaine suivante sont ouverts à la réservation.',
              color: AppColors.gold,
            ),
          const SizedBox(height: 18),
          // Déjà inscrit → bouton de désinscription ; sinon bouton de réservation.
          if (_myBooking != null)
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton.icon(
                onPressed:
                    (_cancelling || course.hasStarted) ? null : _confirmCancel,
                icon: _cancelling
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.danger),
                      )
                    : const Icon(Icons.event_busy, color: AppColors.danger),
                label: const Text('Se désinscrire',
                    style: TextStyle(color: AppColors.danger, fontSize: 16)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.danger),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: (_booking || !_bookable) ? null : _book,
                style: ElevatedButton.styleFrom(
                  backgroundColor: (course.isFull || !_bookable) ? AppColors.surface2 : AppColors.darkGreen,
                  foregroundColor: AppColors.text,
                  disabledBackgroundColor: AppColors.surface2,
                  disabledForegroundColor: AppColors.muted,
                ),
                child: _booking
                    ? const CircularProgressIndicator(color: AppColors.text)
                    : Text(
                        !_bookable
                            ? 'Réservation pas encore ouverte'
                            : (course.isFull ? 'Rejoindre la liste d’attente' : 'Réserver ce cours'),
                      ),
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
      onTap: () => context.push('/coaches/${course.coachId}'),
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

class _ParticipantsCard extends StatelessWidget {
  final List<CourseParticipant> participants;
  const _ParticipantsCard({required this.participants});

  @override
  Widget build(BuildContext context) {
    final confirmed = participants.where((p) => !p.isWaitlist).length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'INSCRITS ($confirmed)',
            style: const TextStyle(
              color: AppColors.gold,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          if (participants.isEmpty)
            const Text('Personne pour le moment',
                style: TextStyle(color: AppColors.muted)),
          ...participants.map(
            (p) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  PgcAvatar(
                    avatarUrl: p.avatarUrl,
                    initials:
                        '${p.firstName.isNotEmpty ? p.firstName[0] : ''}${p.lastName.isNotEmpty ? p.lastName[0] : ''}',
                    radius: 16,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(p.fullName,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  if (p.isWaitlist)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withOpacity(.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('Liste d’attente',
                          style: TextStyle(
                              color: AppColors.gold, fontSize: 11)),
                    ),
                ],
              ),
            ),
          ),
        ],
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
