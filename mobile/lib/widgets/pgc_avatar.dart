import 'package:flutter/material.dart';
import 'package:pgc_app/theme/app_theme.dart';
import 'package:pgc_app/utils/avatar_utils.dart';

class PgcAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String initials;
  final double radius;
  final bool showBorder;

  const PgcAvatar({
    super.key,
    required this.avatarUrl,
    required this.initials,
    this.radius = 34,
    this.showBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: showBorder ? Border.all(color: AppColors.gold, width: 2) : null,
      ),
      child: ClipOval(
        child: Image(
          image: AvatarUtils.provider(avatarUrl),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: AppColors.surface2,
            alignment: Alignment.center,
            child: Text(
              initials.toUpperCase(),
              style: TextStyle(
                color: AppColors.gold,
                fontSize: radius * 0.45,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
