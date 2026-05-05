import 'package:flutter/material.dart';
import 'package:pgc_app/config/api_config.dart';

class AvatarUtils {
  static String? normalize(String? value) {
    final url = value?.trim();
    if (url == null || url.isEmpty) return null;

    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('assets/')) return url;

    if (url.startsWith('/uploads/')) {
      final base = ApiConfig.baseUrl.replaceAll(RegExp(r'/$'), '');
      return '$base$url';
    }

    if (url.startsWith('uploads/')) {
      final base = ApiConfig.baseUrl.replaceAll(RegExp(r'/$'), '');
      return '$base/$url';
    }

    return url;
  }

  static ImageProvider provider(String? value) {
    final url = normalize(value);
    if (url == null || url.isEmpty) {
      return const AssetImage('assets/images/default_avatar.png');
    }

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return NetworkImage(url);
    }

    return AssetImage(url);
  }
}
