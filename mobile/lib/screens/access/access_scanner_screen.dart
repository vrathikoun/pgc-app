import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:pgc_app/providers/auth_provider.dart';
import 'package:pgc_app/services/api_service.dart';
import 'package:pgc_app/theme/app_theme.dart';

/// Scanner d'accès (accueil, réservé au staff coach/admin).
/// Scanne le QR d'un membre et affiche en grand si l'accès est autorisé,
/// avec son nom et le motif — le statut est vérifié en direct côté serveur.
class AccessScannerScreen extends StatefulWidget {
  const AccessScannerScreen({super.key});

  @override
  State<AccessScannerScreen> createState() => _AccessScannerScreenState();
}

class _AccessScannerScreenState extends State<AccessScannerScreen> {
  bool _busy = false;
  Map<String, dynamic>? _result;
  String? _error;

  Future<void> _onScan(Code code) async {
    if (_busy || _result != null || _error != null) return; // un scan à la fois
    final value = code.text;
    if (value == null || value.isEmpty) return;

    setState(() => _busy = true);
    try {
      final res = await context.read<AuthProvider>().api.verifyAccess(value);
      if (!mounted) return;
      setState(() => _result = res);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _reset() {
    setState(() {
      _result = null;
      _error = null;
    });
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
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/profile'),
        ),
        title: const Text('Scanner l’accès',
            style: TextStyle(color: AppColors.text)),
      ),
      body: (_result != null || _error != null)
          ? _buildResult()
          : ReaderWidget(
              onScan: _onScan,
              codeFormat: Format.qrCode,
              showGallery: false,
              showToggleCamera: false,
              showScannerOverlay: true,
              scannerOverlay: const FixedScannerOverlay(
                  borderColor: AppColors.gold, cutOutSize: 260),
              loading: const DecoratedBox(
                decoration: BoxDecoration(color: AppColors.bg),
                child: Center(
                    child: CircularProgressIndicator(color: AppColors.gold)),
              ),
            ),
    );
  }

  Widget _buildResult() {
    if (_error != null) {
      return _ResultView(
        color: AppColors.danger,
        icon: Icons.error_outline,
        title: 'QR non valide',
        subtitle: _error!,
        onNext: _reset,
      );
    }
    final r = _result!;
    final allowed = r['allowed'] == true;
    final name = '${r['first_name'] ?? ''} ${r['last_name'] ?? ''}'.trim();
    final bookings = (r['today_bookings'] is List)
        ? List<Map<String, dynamic>>.from(
            (r['today_bookings'] as List).whereType<Map>().map(Map<String, dynamic>.from))
        : <Map<String, dynamic>>[];
    return _ResultView(
      color: allowed ? AppColors.green : AppColors.danger,
      icon: allowed ? Icons.check_circle : Icons.cancel,
      title: allowed ? 'Accès autorisé' : 'Accès refusé',
      subtitle: '$name\n${r['reason'] ?? ''}',
      todayBookings: bookings,
      onNext: _reset,
    );
  }
}

class _ResultView extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Map<String, dynamic>> todayBookings;
  final VoidCallback onNext;

  const _ResultView({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.todayBookings = const [],
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.12),
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 100),
          const SizedBox(height: 16),
          Text(title,
              style: TextStyle(
                  color: color, fontSize: 30, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.text, fontSize: 18)),
          const SizedBox(height: 20),
          // Cours réservés aujourd'hui : l'accueil vérifie que le membre
          // assiste bien à un cours qu'il a réservé.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cours réservés aujourd’hui',
                    style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (todayBookings.isEmpty)
                  const Text('Aucun cours réservé aujourd’hui ⚠️',
                      style: TextStyle(color: AppColors.gold, fontSize: 16))
                else
                  ...todayBookings.map((b) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Text('${b['time'] ?? ''}',
                                style: const TextStyle(
                                    color: AppColors.gold,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text('${b['course_name'] ?? ''}',
                                  style: const TextStyle(
                                      color: AppColors.text, fontSize: 16)),
                            ),
                            Text(
                              b['status'] == 'waitlist' ? '⏳ attente' : '✅',
                              style: const TextStyle(
                                  color: AppColors.muted, fontSize: 13),
                            ),
                          ],
                        ),
                      )),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surface2,
                foregroundColor: AppColors.text,
              ),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scanner le suivant'),
            ),
          ),
        ],
      ),
    );
  }
}
