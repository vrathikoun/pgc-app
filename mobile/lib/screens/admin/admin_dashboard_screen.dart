import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pgc_app/theme/app_theme.dart';
import 'package:pgc_app/widgets/pgc_admin_card.dart';
import 'package:pgc_app/widgets/pgc_section_header.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const PgcSectionHeader(
              eyebrow: 'Back office',
              title: 'Admin PGC',
              subtitle: 'Cours, planning, coachs et rôles membres.',
            ),
            const SizedBox(height: 28),
            PgcAdminCard(
              icon: Icons.add_circle_outline,
              title: 'Créer un cours',
              subtitle: 'Ajoute une session NoGi, wrestling ou préparation compétition.',
              onTap: () => context.push('/admin/courses/new'),
            ),
            const SizedBox(height: 14),
            PgcAdminCard(
              icon: Icons.calendar_month,
              title: 'Planning',
              subtitle: 'Gère les cours existants, capacités, horaires et coach assigné.',
              onTap: () => context.push('/admin/schedule'),
            ),
            const SizedBox(height: 14),
            PgcAdminCard(
              icon: Icons.people_alt_outlined,
              title: 'Membres & rôles',
              subtitle: 'Passe un membre en coach ou admin.',
              onTap: () => context.push('/admin/members'),
            ),
            const SizedBox(height: 14),
            PgcAdminCard(
              icon: Icons.video_library_outlined,
              title: 'Vidéos Academy',
              subtitle: 'Ajoute, modifie ou supprime les vidéos techniques.',
              onTap: () => context.push('/admin/academy'),
            ),
          ],
        ),
      ),
    );
  }
}
