import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:pgc_app/providers/auth_provider.dart';
import 'package:pgc_app/services/api_service.dart';
import 'package:pgc_app/theme/app_theme.dart';

/// Réinitialisation du mot de passe en deux étapes :
/// 1. saisie de l'email → un code à 6 chiffres est envoyé ;
/// 2. saisie du code + nouveau mot de passe.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _codeSent = false;
  bool _loading = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  ApiService get _api => context.read<AuthProvider>().api;

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Entre une adresse email valide.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _api.forgotPassword(email);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _info = 'Code envoyé ! Vérifie ta boîte mail (et les spams).';
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final code = _codeCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (code.length != 6) {
      setState(() => _error = 'Le code fait 6 chiffres.');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Le mot de passe doit faire au moins 6 caractères.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _api.resetPassword(_emailCtrl.text.trim(), code, password);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mot de passe mis à jour ✅ Connecte-toi.'),
          backgroundColor: AppColors.darkGreen,
        ),
      );
      context.go('/login');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
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
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/login'),
        ),
        title: const Text('Mot de passe oublié',
            style: TextStyle(color: AppColors.text)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _codeSent
                    ? 'Entre le code à 6 chiffres reçu par email et ton nouveau mot de passe.'
                    : 'Entre ton adresse email : on t’envoie un code pour réinitialiser ton mot de passe.',
                style: const TextStyle(color: AppColors.muted, fontSize: 15),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _emailCtrl,
                enabled: !_codeSent,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: AppColors.text),
                decoration: _dec('Email'),
              ),
              if (_codeSent) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _codeCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: const TextStyle(
                      color: AppColors.text, letterSpacing: 8, fontSize: 20),
                  decoration: _dec('Code à 6 chiffres'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  style: const TextStyle(color: AppColors.text),
                  decoration: _dec('Nouveau mot de passe'),
                ),
              ],
              const SizedBox(height: 12),
              if (_error != null)
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.danger)),
              if (_info != null && _error == null)
                Text(_info!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.green)),
              const SizedBox(height: 16),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed:
                      _loading ? null : (_codeSent ? _resetPassword : _sendCode),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.darkGreen,
                    foregroundColor: AppColors.text,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(color: AppColors.text)
                      : Text(
                          _codeSent
                              ? 'Changer mon mot de passe'
                              : 'Envoyer le code',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                ),
              ),
              if (_codeSent)
                TextButton(
                  onPressed: _loading ? null : _sendCode,
                  child: const Text('Renvoyer un code',
                      style: TextStyle(color: AppColors.gold)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.muted),
        counterText: '',
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      );
}
