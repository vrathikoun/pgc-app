import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pgc_app/models/booking.dart';
import 'package:pgc_app/providers/auth_provider.dart';

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
    try {
      final bookings = await context.read<AuthProvider>().api.getMyBookings();
      setState(() {
        _bookings = bookings;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _cancel(int bookingId) async {
    try {
      await context.read<AuthProvider>().api.cancelBooking(bookingId);
      await _loadBookings();
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Mes cours'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
              : _bookings.isEmpty
                  ? const Center(
                      child: Text('Aucune réservation', style: TextStyle(color: Colors.grey)),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadBookings,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _bookings.length,
                        itemBuilder: (_, i) {
                          final booking = _bookings[i];
                          final course = booking.course;

                          return Card(
                            color: const Color(0xFF1E1E1E),
                            child: ListTile(
                              title: Text(
                                course?.name ?? 'Cours #${booking.courseId}',
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                booking.statusLabel,
                                style: const TextStyle(color: Colors.white70),
                              ),
                              trailing: booking.isCancelled
                                  ? null
                                  : IconButton(
                                      icon: const Icon(Icons.cancel, color: Colors.redAccent),
                                      onPressed: () => _cancel(booking.id),
                                    ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}