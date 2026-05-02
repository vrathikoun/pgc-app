import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pgc_app/theme/app_theme.dart';

/// Widget réutilisable : affiche un avatar cliquable qui ouvre un picker.
/// Utilisé dans ProfileScreen et MemberAdminScreen.
///
/// [avatarUrl]   : URL actuelle (null = initiales)
/// [initials]    : texte de fallback (ex: "PD")
/// [radius]      : taille du cercle (défaut 48)
/// [editable]    : si false, lecture seule (pas de crayon)
/// [onUploaded]  : callback appelé avec le base64 une fois l'image prête
class AvatarPicker extends StatelessWidget {
  final String? avatarUrl;
  final String initials;
  final double radius;
  final bool editable;
  final Future<void> Function(String base64Image)? onUploaded;

  const AvatarPicker({
    super.key,
    this.avatarUrl,
    required this.initials,
    this.radius = 48,
    this.editable = true,
    this.onUploaded,
  });

  Future<void> _pick(BuildContext context) async {
    final picker = ImagePicker();
    final source = await _showSourceDialog(context);
    if (source == null) return;

    final XFile? file = await picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (file == null) return;

    // Compresser avant upload
    final compressed = await FlutterImageCompress.compressWithFile(
      file.path,
      minWidth: 400,
      minHeight: 400,
      quality: 80,
      format: CompressFormat.jpeg,
    );
    if (compressed == null) return;

    final b64 = 'data:image/jpeg;base64,${base64Encode(compressed)}';
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
              title: const Text('Prendre une photo',
                  style: TextStyle(color: AppColors.text)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_library, color: AppColors.gold),
              title: const Text('Choisir depuis la galerie',
                  style: TextStyle(color: AppColors.text)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  ImageProvider? _imageProvider() {
    final url = avatarUrl?.trim();
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return NetworkImage(url);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final provider = _imageProvider();

    return GestureDetector(
      onTap: editable ? () => _pick(context) : null,
      child: Stack(
        children: [
          CircleAvatar(
            radius: radius,
            backgroundColor: AppColors.surface2,
            backgroundImage: provider,
            child: provider == null
                ? Text(
                    initials.toUpperCase(),
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: radius * 0.5,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : null,
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