import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pgc_app/models/member.dart';
import 'package:pgc_app/providers/auth_provider.dart';
import 'package:pgc_app/theme/app_theme.dart';
import 'package:pgc_app/widgets/pgc_section_header.dart';

class MemberAdminScreen extends StatefulWidget {
  const MemberAdminScreen({super.key});

  @override
  State<MemberAdminScreen> createState() => _MemberAdminScreenState();
}

class _MemberAdminScreenState extends State<MemberAdminScreen> {
  List<Member> _members = [];
  bool _loading = true;
  String? _error;

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
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (_error != null) Text(_error!, style: const TextStyle(color: AppColors.danger)),
            if (!_loading)
              ..._members.map(
                (m) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.gold.withOpacity(.12)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.green,
                        child: Text(m.firstName.isNotEmpty ? m.firstName[0].toUpperCase() : '?'),
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
                      DropdownButton<String>(
                        value: m.role,
                        dropdownColor: AppColors.surface2,
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(value: 'member', child: Text('Member')),
                          DropdownMenuItem(value: 'coach', child: Text('Coach')),
                          DropdownMenuItem(value: 'admin', child: Text('Admin')),
                        ],
                        onChanged: (value) {
                          if (value != null && value != m.role) _changeRole(m, value);
                        },
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
