import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:pgc_app/providers/auth_provider.dart';
import 'package:pgc_app/theme/app_theme.dart';

/// Carte d'accès du membre : affiche un QR code à présenter à l'accueil.
/// Le jeton est court (5 min) et rafraîchi automatiquement tant que l'écran
/// reste ouvert, pour rester valide au moment du scan.
class AccessCardScreen extends StatefulWidget {
  const AccessCardScreen({super.key});

  @override
  State<AccessCardScreen> createState() => _AccessCardScreenState();
}

class _AccessCardScreenState extends State<AccessCardScreen> {
  String? _token;
  String? _error;
  bool _loading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadToken();
    // Le jeton vaut 5 min : on le renouvelle toutes les 4 min.
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 4),
      (_) => _loadToken(silent: true),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadToken({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final token = await context.read<AuthProvider>().api.getMyAccessQr();
      if (!mounted) return;
      setState(() {
        _token = token;
        _error = null;
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

  @override
  Widget build(BuildContext context) {
    final member = context.watch<AuthProvider>().member;

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
        title: const Text('Ma carte d’accès',
            style: TextStyle(color: AppColors.text)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                member?.fullName ?? '',
                style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 24,
                    fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'Présente ce QR code à l’accueil pour accéder aux cours.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 14),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: _buildQr(),
              ),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: _loading ? null : () => _loadToken(),
                icon: const Icon(Icons.refresh, color: AppColors.gold, size: 20),
                label: const Text('Actualiser',
                    style: TextStyle(color: AppColors.gold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQr() {
    const double size = 260;
    if (_loading && _token == null) {
      return const SizedBox(
        width: size,
        height: size,
        child: Center(
            child: CircularProgressIndicator(color: AppColors.darkGreen)),
      );
    }
    if (_token == null) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(
            _error ?? 'QR indisponible',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
        ),
      );
    }
    return QrImageView(
      data: _token!,
      version: QrVersions.auto,
      size: size,
      backgroundColor: Colors.white,
      // Correction d'erreur haute : reste scannable même un peu abîmé/reflété.
      errorCorrectionLevel: QrErrorCorrectLevel.H,
    );
  }
}
