import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:pgc_app/providers/auth_provider.dart';
import 'package:pgc_app/theme/app_theme.dart';

class AcademyVideo {
  final String title;
  final String section;
  final String youtubeId;
  final String description;

  const AcademyVideo({
    required this.title,
    required this.section,
    required this.youtubeId,
    required this.description,
  });
}

const academySections = [
  'Guard',
  'Passing',
  'Leglocks',
  'Wrestling',
  'Controls',
  'Submissions',
];

const academyVideos = <AcademyVideo>[
  AcademyVideo(
    title: 'Guard Fundamentals',
    section: 'Guard',
    youtubeId: '1PeFhfmlfy4',
    description: 'Concepts de base pour construire une garde solide.',
  ),
  AcademyVideo(
    title: 'Passing Concepts',
    section: 'Passing',
    youtubeId: '1onq-ONSQJk',
    description: 'Principes de pression, angle et contrôle.',
  ),
  AcademyVideo(
    title: 'Leglock Entries',
    section: 'Leglocks',
    youtubeId: 'EWwWb2Ibfsk',
    description: 'Entrées fondamentales vers les entanglements.',
  ),
  AcademyVideo(
    title: 'Wrestling for NoGi',
    section: 'Wrestling',
    youtubeId: '23EReOYK6Ww',
    description: 'Hand fighting, stance et premières attaques.',
  ),
  AcademyVideo(
    title: 'Top Controls',
    section: 'Controls',
    youtubeId: '8FbGenSia08',
    description: 'Contrôler sans se faire remettre en garde.',
  ),
  AcademyVideo(
    title: 'Submission Basics',
    section: 'Submissions',
    youtubeId: 'dQw4w9WgXcQ',
    description: 'Finitions propres et mécaniques de soumission.',
  ),
];

class AcademyScreen extends StatelessWidget {
  const AcademyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final member = context.watch<AuthProvider>().member;
    final hasAccess = member?.subscriptionPlan == 'unlimited';

    if (!hasAccess) {
      return const _AcademyLockedScreen();
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 36, 24, 120),
          children: [
            const Text(
              'PGC Academy',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 42,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Vidéos techniques réservées aux membres illimités.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 16,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 34),
            ...academySections.map((section) {
              final count =
                  academyVideos.where((v) => v.section == section).length;

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => context.go(
                    '/academy/${Uri.encodeComponent(section)}',
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                section,
                                style: const TextStyle(
                                  color: AppColors.text,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '$count vidéo${count > 1 ? 's' : ''}',
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: AppColors.gold,
                          size: 32,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _AcademyLockedScreen extends StatelessWidget {
  const _AcademyLockedScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.lock, color: AppColors.gold, size: 42),
                SizedBox(height: 18),
                Text(
                  'Academy réservée aux abonnements illimités',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Passe en abonnement illimité pour accéder aux vidéos techniques PGC.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}