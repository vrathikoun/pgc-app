import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:pgc_app/models/academy_video.dart';
import 'package:pgc_app/providers/auth_provider.dart';
import 'package:pgc_app/theme/app_theme.dart';

class AcademyScreen extends StatefulWidget {
  const AcademyScreen({super.key});

  @override
  State<AcademyScreen> createState() => _AcademyScreenState();
}

class _AcademyScreenState extends State<AcademyScreen> {
  List<AcademyVideo>? _videos;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final videos = await context.read<AuthProvider>().api.getAcademyVideos();
      if (mounted) setState(() => _videos = videos);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final member = context.watch<AuthProvider>().member;
    final hasAccess = member?.subscriptionPlan == 'unlimited';

    if (!hasAccess) return const _AcademyLockedScreen();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.gold,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: AppColors.muted)),
      );
    }

    if (_videos == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.gold));
    }

    final sections = _videos!.map((v) => v.section).toSet().toList()..sort();

    return ListView(
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
          style: TextStyle(color: AppColors.muted, fontSize: 16, height: 1.3),
        ),
        const SizedBox(height: 34),
        if (sections.isEmpty)
          const Text(
            'Aucune vidéo disponible pour le moment.',
            style: TextStyle(color: AppColors.muted),
          )
        else
          ...sections.map((section) {
            final count = _videos!.where((v) => v.section == section).length;
            final sectionVideos = _videos!.where((v) => v.section == section).toList();

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => context.push(
                  '/academy/${Uri.encodeComponent(section)}',
                  extra: sectionVideos,
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
                      const Icon(Icons.chevron_right, color: AppColors.gold, size: 32),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
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
