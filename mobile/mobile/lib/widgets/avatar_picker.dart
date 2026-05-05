import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pgc_app/theme/app_theme.dart';
import 'package:pgc_app/widgets/pgc_avatar.dart';

/// Avatar cliquable : choisit une image et envoie une data URL base64 à l'API.
/// Compatible Web / Android / iOS car il utilise XFile.readAsBytes().
class AvatarPicker extends StatelessWidget {
  final String? avatarUrl;
  final String initials;
  final double radius;
  final bool editable;
  final String apiBaseUrl;
  final Future<void> Function(String base64Image)? onUploaded;

  const AvatarPicker({
    super.key,
    this.avatarUrl,
    required this.initials,
    required this.apiBaseUrl,
    this.radius = 48,
    this.editable = true,
    this.onUploaded,
  });

  Future<void> _pick(BuildContext context) async {
    final picker = ImagePicker();
    final source = await _showSourceDialog(context);
    if (source == null) return;

    final file = await picker.pickImage(
      source: source,
      maxWidth: 900,
      maxHeight: 900,
      imageQuality: 85,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    final extension = file.name.split('.').last.toLowerCase();
    final mime = switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'jpg' || 'jpeg' => 'image/jpeg',
      _ => 'image/jpeg',
    };

    final b64 = 'data:$mime;base64,${base64Encode(bytes)}';
    await onUploaded?.call(b64);
  }

  Future<ImageSource?> _showSourceDialog(BuildContext context) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.photo_camera, color: AppColors.gold),
              title: const Text(
                'Prendre une photo',
                style: TextStyle(color: AppColors.text),
              ),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.gold),
              title: const Text(
                'Choisir depuis la galerie',
                style: TextStyle(color: AppColors.text),
              ),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: editable ? () => _pick(context) : null,
      child: Stack(
        children: [
          PgcAvatar(
            avatarUrl: avatarUrl,
            initials: initials,
            radius: radius,
            apiBaseUrl: apiBaseUrl,
            showBorder: true,
          ),
          if (editable)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: radius * 0.65,
                height: radius * 0.65,
                decoration: const BoxDecoration(
                  color: AppColors.gold,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.camera_alt,
                  color: Colors.black,
                  size: radius * 0.35,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
