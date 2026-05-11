import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import 'package:pgc_app/screens/academy/academy_screen.dart';
import 'package:pgc_app/theme/app_theme.dart';

class AcademySectionScreen extends StatelessWidget {
  final String section;

  const AcademySectionScreen({
    super.key,
    required this.section,
  });

  List<AcademyVideo> get _videos {
    return academyVideos.where((v) => v.section == section).toList();
  }

  @override
  Widget build(BuildContext context) {
    final videos = _videos;

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
              context.go('/academy');
            }
          },
        ),
        title: Text(
          section,
          style: const TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 120),
          children: [
            Text(
              '${videos.length} vidéo${videos.length > 1 ? 's' : ''}',
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            if (videos.isEmpty)
              const Text(
                'Aucune vidéo dans cette section pour le moment.',
                style: TextStyle(color: AppColors.muted),
              )
            else
              ...videos.map(
                (video) => _AcademyVideoCard(video: video),
              ),
          ],
        ),
      ),
    );
  }
}

class _AcademyVideoCard extends StatelessWidget {
  final AcademyVideo video;

  const _AcademyVideoCard({
    required this.video,
  });

  @override
  Widget build(BuildContext context) {
    final thumbnail =
        'https://img.youtube.com/vi/${video.youtubeId}/hqdefault.jpg';

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AcademyVideoPlayerScreen(video: video),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    thumbnail,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.surface2,
                      child: const Center(
                        child: Icon(Icons.play_circle, color: AppColors.gold),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.black,
                    size: 34,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    video.description,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AcademyVideoPlayerScreen extends StatefulWidget {
  final AcademyVideo video;

  const AcademyVideoPlayerScreen({
    super.key,
    required this.video,
  });

  @override
  State<AcademyVideoPlayerScreen> createState() =>
      _AcademyVideoPlayerScreenState();
}

class _AcademyVideoPlayerScreenState extends State<AcademyVideoPlayerScreen> {
  late final YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();

    _controller = YoutubePlayerController(
      initialVideoId: widget.video.youtubeId,
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
        enableCaption: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _controller,
        showVideoProgressIndicator: true,
        progressIndicatorColor: AppColors.gold,
      ),
      builder: (context, player) {
        return Scaffold(
          backgroundColor: AppColors.bg,
          appBar: AppBar(
            backgroundColor: AppColors.bg,
            elevation: 0,
            iconTheme: const IconThemeData(color: AppColors.text),
            title: Text(
              widget.video.title,
              style: const TextStyle(color: AppColors.text),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 40),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: player,
              ),
              const SizedBox(height: 20),
              Text(
                widget.video.section,
                style: const TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.video.title,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.video.description,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}