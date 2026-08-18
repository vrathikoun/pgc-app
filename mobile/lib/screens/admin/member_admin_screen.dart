import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pgc_app/models/member.dart';
import 'package:pgc_app/providers/auth_provider.dart';
import 'package:pgc_app/theme/app_theme.dart';
import 'package:pgc_app/widgets/pgc_section_header.dart';
import 'package:pgc_app/widgets/pgc_avatar.dart';

class MemberAdminScreen extends StatefulWidget {
  const MemberAdminScreen({super.key});

  @override
  State<MemberAdminScreen> createState() => _MemberAdminScreenState();
}

class _MemberAdminScreenState extends State<MemberAdminScreen> {
  List<Member> _members = [];
  bool _loading = true;
  String? _error;
  String _search = '';
  String? _beltFilter; // null = toutes

  static const _beltLabels = {
    'white': 'Blanche',
    'blue': 'Bleue',
    'purple': 'Violette',
    'brown': 'Marron',
    'black': 'Noire',
  };

  List<Member> get _filtered {
    final q = _search.trim().toLowerCase();
    return _members.where((m) {
      if (_beltFilter != null && m.beltRank != _beltFilter) return false;
      if (q.isEmpty) return true;
      return m.firstName.toLowerCase().contains(q) ||
          m.lastName.toLowerCase().contains(q) ||
          m.email.toLowerCase().contains(q);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<AuthProvider>().api.getMembers(limit: 200);
      setState(() => _members = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeRole(Member member, String role) async {
    try {
      await context.read<AuthProvider>().api.updateMemberRole(member.id, role);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${member.fullName} est maintenant $role')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Membres')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const PgcSectionHeader(
              eyebrow: 'Staff access',
              title: 'Rôles membres',
              subtitle: 'Member, coach ou admin.',
            ),
            const SizedBox(height: 20),
            TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Rechercher (nom, prénom, email)…',
                prefixIcon: const Icon(Icons.search, color: AppColors.muted),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('Toutes'),
                    selected: _beltFilter == null,
                    onSelected: (_) => setState(() => _beltFilter = null),
                  ),
                  ..._beltLabels.entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ChoiceChip(
                        label: Text(e.value),
                        selected: _beltFilter == e.key,
                        onSelected: (_) => setState(() => _beltFilter = e.key),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (!_loading && _error == null && _filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(
                  child: Text('Aucun membre ne correspond',
                      style: TextStyle(color: AppColors.muted)),
                ),
              ),
            if (_error != null) Text(_error!, style: const TextStyle(color: AppColors.danger)),
            if (!_loading)
              ..._filtered.map(
                (m) => GestureDetector(
                  onTap: () => context.push('/admin/members/${m.id}'),
                  child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.gold.withOpacity(.12)),
                  ),
                  child: Row(
                    children: [
                      PgcAvatar(
                        avatarUrl: m.avatarUrl,
                        initials: '${m.firstName.isNotEmpty ? m.firstName[0] : ''}${m.lastName.isNotEmpty ? m.lastName[0] : ''}',
                        radius: 22,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.fullName, style: const TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text(m.email, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          _RoleBadge(role: m.role),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right, color: AppColors.muted, size: 18),
                        ],
                      ),
                    ],
                  ),
                ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final colors = {
      "admin": AppColors.gold,
      "coach": AppColors.green,
      "member": AppColors.muted,
    };
    final color = colors[role] ?? AppColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        role,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}