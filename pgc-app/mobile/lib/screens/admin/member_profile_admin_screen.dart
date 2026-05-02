import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:pgc_app/models/member.dart';
import 'package:pgc_app/providers/auth_provider.dart';
import 'package:pgc_app/services/api_service.dart';
import 'package:pgc_app/theme/app_theme.dart';
import 'package:pgc_app/widgets/avatar_picker.dart';

class MemberProfileAdminScreen extends StatefulWidget {
  final int memberId;
  const MemberProfileAdminScreen({super.key, required this.memberId});

  @override
  State<MemberProfileAdminScreen> createState() =>
      _MemberProfileAdminScreenState();
}

class _MemberProfileAdminScreenState extends State<MemberProfileAdminScreen> {
  Member? _member;
  bool _loading = true;
  bool _saving = false;
  bool _uploadingAvatar = false;
  String? _error;

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String? _selectedRole;
  String? _selectedBelt;

  static const _roles = ['member', 'coach', 'admin'];
  static const _belts = [
    'white', 'blue', 'purple', 'brown', 'black',
    'beginner', 'intermediate', 'advanced', 'elite',
  ];
  static const _beltLabels = {
    'white': 'Blanche', 'blue': 'Bleue', 'purple': 'Violette',
    'brown': 'Marron', 'black': 'Noire',
    'beginner': 'Débutant', 'intermediate': 'Intermédiaire',
    'advanced': 'Avancé', 'elite': 'Élite',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = context.read<AuthProvider>().api;
      // On utilise GET /members/{id} (admin)
      final members = await api.getMembers(limit: 500);
      final member = members.firstWhere((m) => m.id == widget.memberId);
      _member = member;
      _firstNameCtrl.text = member.firstName;
      _lastNameCtrl.text = member.lastName;
      _phoneCtrl.text = member.phone ?? '';
      _selectedRole = member.role;
      _selectedBelt = member.beltRank ?? 'white';
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_member == null) return;
    setState(() => _saving = true);
    try {
      final api = context.read<AuthProvider>().api;

      // Mettre à jour le profil
      final updated = await api.updateMember(
        _member!.id,
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        beltRank: _selectedBelt,
      );

      // Mettre à jour le rôle si changé
      if (_selectedRole != null && _selectedRole != _member!.role) {
        await api.updateMemberRole(_member!.id, _selectedRole!);
      }

      setState(() => _member = updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil mis à jour ✅'),
            backgroundColor: AppColors.darkGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _onAvatarUploaded(String base64Image) async {
    if (_member == null) return;
    setState(() => _uploadingAvatar = true);
    try {
      final api = context.read<AuthProvider>().api;
      final updated = await api.uploadMemberAvatar(_member!.id, base64Image);
      setState(() => _member = updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo mise à jour ✅'),
            backgroundColor: AppColors.darkGreen,
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  String? _fullUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return url;
    final base = context.read<AuthProvider>().api.baseUrl.replaceAll(RegExp(r'/$'), '');
    return '$base$url';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(_member?.fullName ?? 'Profil membre'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin/members'),
        ),
        actions: [
          if (!_saving)
            TextButton(
              onPressed: _save,
              child: const Text('Enregistrer',
                  style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800)),
            )
          else
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.danger)))
              : _buildForm(),
    );
  }

  Widget _buildForm() {
    final member = _member!;
    final initials =
        '${member.firstName.isNotEmpty ? member.firstName[0] : ""}${member.lastName.isNotEmpty ? member.lastName[0] : ""}';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Avatar ────────────────────────────────────────────────────────
          if (_uploadingAvatar)
            const SizedBox(
              width: 96, height: 96,
              child: CircularProgressIndicator(color: AppColors.gold),
            )
          else
            AvatarPicker(
              avatarUrl: _fullUrl(member.avatarUrl),
              initials: initials,
              radius: 48,
              editable: true,
              onUploaded: _onAvatarUploaded,
            ),

          const SizedBox(height: 8),
          Text(
            member.email,
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 28),

          // ── Champs éditables ──────────────────────────────────────────────
          _Section(title: 'Informations', children: [
            _Field(label: 'Prénom', controller: _firstNameCtrl),
            const SizedBox(height: 12),
            _Field(label: 'Nom', controller: _lastNameCtrl),
            const SizedBox(height: 12),
            _Field(
              label: 'Téléphone',
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
            ),
          ]),

          const SizedBox(height: 20),

          // ── Rôle ──────────────────────────────────────────────────────────
          _Section(title: 'Rôle', children: [
            _DropdownField<String>(
              value: _selectedRole,
              items: _roles,
              labelFor: (r) => const {
                'member': '🏋️ Membre',
                'coach': '🥊 Coach',
                'admin': '👑 Admin',
              }[r] ?? r,
              onChanged: (v) => setState(() => _selectedRole = v),
            ),
          ]),

          const SizedBox(height: 20),

          // ── Ceinture ──────────────────────────────────────────────────────
          _Section(title: 'Niveau / Ceinture', children: [
            _DropdownField<String>(
              value: _selectedBelt,
              items: _belts,
              labelFor: (b) => _beltLabels[b] ?? b,
              onChanged: (v) => setState(() => _selectedBelt = v),
            ),
          ]),

          const SizedBox(height: 20),

          // ── Statut abonnement (lecture seule) ─────────────────────────────
          _Section(title: 'Abonnement', children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.card_membership, color: AppColors.gold, size: 18),
                  const SizedBox(width: 12),
                  Text(
                    _subLabel(member.subscriptionStatus),
                    style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ]),

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const CircularProgressIndicator(color: Colors.black)
                  : const Text('Enregistrer les modifications'),
            ),
          ),
        ],
      ),
    );
  }

  String _subLabel(String s) => const {
    'active': '✅ Actif',
    'inactive': '❌ Inactif',
    'trial': '🎁 Période d\'essai',
    'suspended': '⚠️ Suspendu',
  }[s] ?? s;
}

// ── Composants locaux ─────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(children: children),
          ),
        ],
      );
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  const _Field({required this.label, required this.controller, this.keyboardType});

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: AppColors.text),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      );
}

class _DropdownField<T> extends StatelessWidget {
  final T? value;
  final List<T> items;
  final String Function(T) labelFor;
  final void Function(T?) onChanged;

  const _DropdownField({
    required this.value,
    required this.items,
    required this.labelFor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: AppColors.surface2,
          style: const TextStyle(color: AppColors.text, fontSize: 15),
          items: items
              .map((item) => DropdownMenuItem<T>(
                    value: item,
                    child: Text(labelFor(item)),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      );
}