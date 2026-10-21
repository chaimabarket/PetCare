import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Avatar rond avec les initiales de l'utilisateur.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.initials, this.radius = 16, this.online = false});

  final String initials;
  final double radius;

  /// Affiche la pastille verte « connecté » en bas à droite.
  final bool online;

  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF005C55),
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: radius * 0.7,
        ),
      ),
    );
    if (!online) return avatar;

    final dot = radius * 0.32;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: radius * 0.04,
          bottom: radius * 0.04,
          child: Container(
            width: dot,
            height: dot,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.teal, width: dot * 0.25),
            ),
          ),
        ),
      ],
    );
  }
}
