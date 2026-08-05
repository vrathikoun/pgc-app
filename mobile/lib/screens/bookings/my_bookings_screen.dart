import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:pgc_app/models/booking.dart';
import 'package:pgc_app/providers/auth_provider.dart';
import 'package:pgc_app/theme/app_theme.dart';
import 'package:pgc_app/widgets/pgc_avatar.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  List<Booking> _bookings = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final bookings = await context.read<AuthProvider>().api.getMyBookings();
      setState(() {
        _bookings = bookings;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _cancel(Booking booking) async {
    // Confirmation, avec avertissement si l'annulation est tardive (< 2h).
    final start = booking.course?.startTime;
    final soon = start != null &&
        start.difference(DateTime.now()) < const Duration(hours: 2);
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

    try {
      await context.read<AuthProvider>().api.cancelBooking(booking.id);
      await _loadBookings();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = _bookings
        .where((b) => b.course != null && !b.course!.isPast && !b.isCancelled)
        .toList()
      // Le prochain cours d'abord (ordre chronologique croissant).
      ..sort((a, b) => a.course!.startTime.compareTo(b.course!.startTime));
    final history = _bookings
        .where((b) => b.course == null || b.course!.isPast || b.isCancelled)
        .toList();

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
          'Mes réservations',
          style: TextStyle(color: AppColors.text),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadBookings,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
            : ListView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 110),
                children: [
                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: AppColors.danger)),
                    const SizedBox(height: 12),
                  ],
                  const Text(
                    'À venir',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (upcoming.isEmpty)
                    const _EmptyBox('Aucune réservation à venir.')
                  else
                    ...upcoming.map(
                      (booking) => _BookingCard(
                        booking: booking,
                        onCancel: booking.canCancel ? () => _cancel(booking) : null,
                      ),
                    ),
                  const SizedBox(height: 28),
                  const Text(
                    'Historique',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (history.isEmpty)
                    const _EmptyBox('Aucun cours dans l’historique.')
                  else
                    ...history.map(
                      (booking) => _BookingCard(
                        booking: booking,
                        onCancel: null,
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Booking booking;
  final VoidCallback? onCancel;

  const _BookingCard({required this.booking, this.onCancel});

  @override
  Widget build(BuildContext context) {
    final course = booking.course;
    final date = course != null
        ? DateFormat('EEE d MMM · HH:mm', 'fr_FR').format(course.startTime)
        : 'Cours #${booking.courseId}';

    final coachName = course?.coachFullName ?? 'Coach à assigner';
    final coachAvatar = course?.effectiveCoachAvatarUrl;
    final coachInitials = course?.coachInitials ?? 'PGC';
    final hasCoachProfile = course?.coachId != null;

    return GestureDetector(
      onTap: course == null ? null : () => context.push('/courses/${course.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course?.name ?? 'Cours #${booking.courseId}',
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$date · ${booking.statusLabel}',
                        style: const TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                      if (course?.hasStarted == true && !booking.isCancelled)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                            'Annulation fermée',
                            style: TextStyle(
                              color: AppColors.gold,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (onCancel != null)
                  IconButton(
                    icon: const Icon(Icons.cancel, color: AppColors.danger),
                    onPressed: onCancel,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: hasCoachProfile
                  ? () => context.push('/coaches/${course!.coachId}')
                  : null,
              child: Row(
                children: [
                  PgcAvatar(
                    avatarUrl: coachAvatar,
                    initials: coachInitials,
                    radius: 18,
                    showBorder: true,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Coach',
                          style: TextStyle(color: AppColors.muted, fontSize: 11),
                        ),
                        Text(
                          coachName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasCoachProfile)
                    const Icon(Icons.chevron_right, color: AppColors.muted, size: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  final String text;

  const _EmptyBox(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(text, style: const TextStyle(color: AppColors.muted)),
    );
  }
}
