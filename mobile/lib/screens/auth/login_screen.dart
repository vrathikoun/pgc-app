import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:pgc_app/providers/auth_provider.dart';
import 'package:pgc_app/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _rememberMe = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();

    final ok = await auth.login(
      _emailCtrl.text.trim(),
      _passwordCtrl.text,
      rememberMe: _rememberMe,
    );

    if (ok && mounted) context.go('/courses');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Image.asset(
                    'assets/images/pgc_logo.png',
                    width: 92,
                    height: 92,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const CircleAvatar(
                      radius: 46,
                      backgroundColor: AppColors.surface,
                      child: Text('PGC', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                const Text(
                  'Polo Grappling Club',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.text, fontSize: 32, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Connecte-toi à ton espace membre',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 15),
                ),
                const SizedBox(height: 36),
                _buildField(controller: _emailCtrl, label: 'Email', keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 16),
                _buildField(
                  controller: _passwordCtrl,
                  label: 'Mot de passe',
                  obscure: _obscure,
                  suffix: IconButton(
                    icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off, color: AppColors.muted),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                if (auth.error != null) ...[
                  const SizedBox(height: 14),
                  Text(auth.error!, style: const TextStyle(color: AppColors.danger), textAlign: TextAlign.center),
                ],
                CheckboxListTile(
                  value: _rememberMe,
                  activeColor: AppColors.gold,
                  checkColor: Colors.black,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Se souvenir de moi',
                    style: TextStyle(color: AppColors.text),
                  ),
                  subtitle: const Text(
                    'Rester connecté sur ce téléphone',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                  onChanged: (v) {
                    setState(() => _rememberMe = v ?? true);
                  },
                ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: auth.loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.darkGreen,
                      foregroundColor: AppColors.text,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    child: auth.loading
                        ? const CircularProgressIndicator(color: AppColors.text)
                        : const Text('Se connecter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.push('/forgot-password'),
                  child: const Text('Mot de passe oublié ?', style: TextStyle(color: AppColors.muted)),
                ),
                TextButton(
                  onPressed: () => context.go('/register'),
                  child: const Text('Pas encore de compte ? S’inscrire', style: TextStyle(color: AppColors.gold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: const TextStyle(color: AppColors.text),
      decoration: InputDecoration(labelText: label, suffixIcon: suffix),
    );
  }
}
