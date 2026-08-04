import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
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
  final MobileScannerController _controller = MobileScannerController();
  bool _busy = false;
  Map<String, dynamic>? _result;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy || _result != null) return; // un scan à la fois
    final code = capture.barcodes.isNotEmpty
        ? capture.barcodes.first.rawValue
        : null;
    if (code == null || code.isEmpty) return;

    setState(() => _busy = true);
    try {
      final res = await context.read<AuthProvider>().api.verifyAccess(code);
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
          : Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(controller: _controller, onDetect: _onDetect),
                _ScannerOverlay(busy: _busy),
              ],
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
    return _ResultView(
      color: allowed ? AppColors.green : AppColors.danger,
      icon: allowed ? Icons.check_circle : Icons.cancel,
      title: allowed ? 'Accès autorisé' : 'Accès refusé',
      subtitle: '$name\n${r['reason'] ?? ''}',
      onNext: _reset,
    );
  }
}

class _ResultView extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onNext;

  const _ResultView({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
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
          Icon(icon, color: color, size: 120),
          const SizedBox(height: 20),
          Text(title,
              style: TextStyle(
                  color: color, fontSize: 30, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.text, fontSize: 18)),
          const SizedBox(height: 40),
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

class _ScannerOverlay extends StatelessWidget {
  final bool busy;
  const _ScannerOverlay({required this.busy});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 260,
          height: 260,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.gold, width: 3),
            borderRadius: BorderRadius.circular(24),
          ),
          child: busy
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.gold))
              : null,
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            busy ? 'Vérification…' : 'Vise le QR code du membre',
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
        ),
      ],
    );
  }
}
