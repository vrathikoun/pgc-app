import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:pgc_app/providers/auth_provider.dart';
import 'package:pgc_app/theme/app_theme.dart';
import 'package:pgc_app/widgets/avatar_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _uploading = false;
  bool _deleting = false;

  Future<void> _editEmergencyContact() async {
    final auth = context.read<AuthProvider>();
    final ctrl = TextEditingController(text: auth.member?.emergencyContact ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Contact d’urgence',
            style: TextStyle(color: AppColors.text)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.phone,
          autofocus: true,
          style: const TextStyle(color: AppColors.text),
          decoration: const InputDecoration(
            hintText: 'Numéro de téléphone',
            hintStyle: TextStyle(color: AppColors.muted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Enregistrer',
                style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );
    if (value == null || !mounted) return;
    try {
      final updated = await auth.api.updateMe(emergencyContact: value);
      await auth.refreshMember(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contact d’urgence mis à jour ✅'),
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
    }
  }

  Future<void> _onAvatarUploaded(String base64Image) async {
    setState(() => _uploading = true);
    try {
      final auth = context.read<AuthProvider>();
      final updated = await auth.api.uploadMyAvatar(base64Image);
      await auth.refreshMember(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo mise à jour ✅'),
            backgroundColor: AppColors.darkGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final member = auth.member;

    if (member == null) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.gold)),
      );
    }

    final initials =
        '${member.firstName.isNotEmpty ? member.firstName[0] : ""}${member.lastName.isNotEmpty ? member.lastName[0] : ""}';

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
        'Mon profil',
        style: TextStyle(color: AppColors.text),
      ),
    ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (_uploading)
                const SizedBox(
                  width: 96,
                  height: 96,
                  child: CircularProgressIndicator(color: AppColors.gold),
                )
              else
                AvatarPicker(
                  avatarUrl: _fullUrl(auth, member.avatarUrl),
                  initials: initials,
                  radius: 48,
                  editable: true,
                  onUploaded: _onAvatarUploaded,
                ),
              const SizedBox(height: 16),
              Text(
                member.fullName,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(member.email,
                  style: const TextStyle(color: AppColors.muted, fontSize: 14)),
              const SizedBox(height: 24),
              if (member.beltRank != null) ...[
                _BeltBadge(belt: member.beltRank!),
                const SizedBox(height: 20),
              ],
              _InfoCard(children: [
                _InfoRow(
                  icon: Icons.card_membership,
                  label: 'Abonnement',
                  value: _planLabel(member.subscriptionPlan),
                  valueColor: AppColors.gold,
                ),
                _Sep(),
                _InfoRow(
                  icon: Icons.shield,
                  label: 'Rôle',
                  value: _roleLabel(member.role),
                ),
                if (member.phone != null) ...[
                  _Sep(),
                  _InfoRow(
                    icon: Icons.phone,
                    label: 'Téléphone',
                    value: member.phone!,
                  ),
                ],
                _Sep(),
                _EditableRow(
                  icon: Icons.emergency,
                  label: 'Contact d’urgence',
                  value: (member.emergencyContact?.isNotEmpty ?? false)
                      ? member.emergencyContact!
                      : 'Non renseigné',
                  onEdit: _editEmergencyContact,
                ),
              ]),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/access/card'),
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('Ma carte d’accès',
                      style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.darkGreen,
                    foregroundColor: AppColors.text,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              if (member.isAdmin || member.isCoach) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/access/scan'),
                    icon: const Icon(Icons.qr_code_scanner, color: AppColors.gold),
                    label: const Text('Scanner l’accès',
                        style: TextStyle(color: AppColors.gold, fontSize: 16)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.gold),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await auth.logout();
                    if (context.mounted) context.go('/login');
                  },
                  icon: const Icon(Icons.logout, color: AppColors.danger),
                  label: const Text('Se déconnecter',
                      style: TextStyle(color: AppColors.danger, fontSize: 16)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.danger),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton.icon(
                  onPressed: _deleting ? null : _confirmDeleteAccount,
                  icon: _deleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.muted),
                        )
                      : const Icon(Icons.delete_forever,
                          color: AppColors.muted, size: 20),
                  label: const Text('Supprimer mon compte',
                      style: TextStyle(color: AppColors.muted, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Supprimer mon compte',
            style: TextStyle(color: AppColors.text)),
        content: const Text(
          'Cette action est définitive. Ton compte et toutes tes données '
          '(réservations, profil) seront supprimés immédiatement et sans '
          'possibilité de récupération.',
          style: TextStyle(color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler',
                style: TextStyle(color: AppColors.text)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer définitivement',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      final auth = context.read<AuthProvider>();
      await auth.api.deleteMyAccount();
      await auth.logout();
      if (mounted) context.go('/login');
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Suppression impossible : $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  String? _fullUrl(AuthProvider auth, String? url) {
    final clean = url?.trim();
    if (clean == null || clean.isEmpty) return null;
    if (clean.startsWith('http')) return clean;
    if (clean.startsWith('assets/')) return clean;
    final base = auth.api.baseUrl.replaceAll(RegExp(r'/$'), '');
    if (clean.startsWith('/')) return '$base$clean';
    return '$base/$clean';
  }

  // Libellé du plan d'abonnement (mêmes valeurs que la page admin).
  String _planLabel(String plan) => const {
        'unlimited': '♾️ Illimité',
        'two_per_week': '2 cours / semaine',
      }[plan] ??
      plan;

  String _roleLabel(String r) =>
      const {'admin': '👑 Admin', 'coach': '🥊 Coach', 'member': '🏋️ Membre'}[r] ?? r;
}

class _BeltBadge extends StatelessWidget {
  final String belt;
  const _BeltBadge({required this.belt});

  static const _labels = {
    'white': 'Ceinture Blanche',
    'blue': 'Ceinture Bleue',
    'purple': 'Ceinture Violette',
    'brown': 'Ceinture Marron',
    'black': 'Ceinture Noire'
  };

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forBelt(belt);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 8,
            decoration:
                BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 10),
          Text(
            _labels[belt] ?? belt,
            style: const TextStyle(
                color: AppColors.text, fontWeight: FontWeight.w800, fontSize: 14),
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
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(children: children),
      );
}

class _EditableRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onEdit;

  const _EditableRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: AppColors.gold, size: 20),
              const SizedBox(width: 14),
              Text(label,
                  style: const TextStyle(color: AppColors.muted, fontSize: 13)),
              const Spacer(),
              Flexible(
                child: Text(value,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.edit, color: AppColors.muted, size: 18),
            ],
          ),
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow(
      {required this.icon,
      required this.label,
      required this.value,
      this.valueColor});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: AppColors.gold, size: 20),
            const SizedBox(width: 14),
            Text(label,
                style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            const Spacer(),
            Text(value,
                style: TextStyle(
                    color: valueColor ?? AppColors.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
          ],
        ),
      );
}

class _Sep extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      const Divider(color: AppColors.border, height: 1, indent: 54);
}