import 'package:flutter/material.dart';

import 'package:pgc_app/theme/app_theme.dart';

String? resolvePgcImageUrl(String? rawUrl, String apiBaseUrl) {
  final value = rawUrl?.trim();
  if (value == null || value.isEmpty) return null;

  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }

  // Flutter assets are resolved locally by the app bundle.
  if (value.startsWith('assets/')) {
    return value;
  }

  final base = apiBaseUrl.replaceAll(RegExp(r'/$'), '');

  // Uploaded avatars are served by FastAPI StaticFiles.
  if (value.startsWith('/')) {
    return '$base$value';
  }

  if (value.startsWith('uploads/')) {
    return '$base/$value';
  }

  return value;
}

class PgcAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String initials;
  final double radius;
  final String apiBaseUrl;
  final bool showBorder;

  const PgcAvatar({
    super.key,
    required this.avatarUrl,
    required this.initials,
    required this.apiBaseUrl,
    this.radius = 34,
    this.showBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = resolvePgcImageUrl(avatarUrl, apiBaseUrl);
    final size = radius * 2;

    Widget fallback() {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: AppColors.surface2,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          initials.toUpperCase(),
          style: TextStyle(
            color: AppColors.gold,
            fontSize: radius * 0.45,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }

    Widget image;
    if (resolvedUrl == null) {
      image = fallback();
    } else if (resolvedUrl.startsWith('assets/')) {
      image = Image.asset(
        resolvedUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, error, __) {
          debugPrint('PGC ASSET AVATAR ERROR: $resolvedUrl => $error');
          return fallback();
        },
      );
    } else {
      image = Image.network(
        resolvedUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, error, __) {
          debugPrint('PGC NETWORK AVATAR ERROR: $resolvedUrl => $error');
          return fallback();
        },
      );
    }

    return Container(
      width: size,
      height: size,
      padding: showBorder ? const EdgeInsets.all(2) : EdgeInsets.zero,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: showBorder ? Border.all(color: AppColors.gold, width: 2) : null,
      ),
      child: ClipOval(child: image),
    );
  }
}
