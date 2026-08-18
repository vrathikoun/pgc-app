import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pgc_app/providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emergencyCtrl = TextEditingController();
  bool _obscure = true;
  String? _fieldError;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _emergencyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Contact d'urgence obligatoire (sécurité : sport de combat).
    if (_emergencyCtrl.text.trim().isEmpty) {
      setState(() => _fieldError =
          'Le contact d\'urgence est obligatoire (personne à prévenir).');
      return;
    }
    setState(() => _fieldError = null);
    final auth = context.read<AuthProvider>();
    final ok = await auth.register(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      firstName: _firstNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim(),
      emergencyContact: _emergencyCtrl.text.trim(),
    );
    if (ok && mounted) context.go('/courses');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Créer un compte',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),

              Row(
                children: [
                  Expanded(
                    child: _buildField(
                      controller: _firstNameCtrl,
                      label: 'Prénom',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildField(
                      controller: _lastNameCtrl,
                      label: 'Nom',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildField(
                controller: _emailCtrl,
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              _buildField(
                controller: _passwordCtrl,
                label: 'Mot de passe',
                obscure: _obscure,
                suffix: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              const SizedBox(height: 16),
              _buildField(
                controller: _emergencyCtrl,
                label: 'Contact d’urgence (téléphone) *',
                keyboardType: TextInputType.phone,
              ),

              if (_fieldError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_fieldError!,
                      style: const TextStyle(color: Colors.redAccent)),
                ),
              if (auth.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(auth.error!,
                      style: const TextStyle(color: Colors.redAccent)),
                ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: auth.loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: auth.loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'S\'inscrire',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                ),
              ),
            ],
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
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[400]),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}