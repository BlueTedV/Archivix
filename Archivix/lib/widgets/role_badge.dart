import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

/// Determines the display role from a profile map.
/// Priority: admin (from app_metadata) > professor > member
enum UserRole { admin, professor, member }

UserRole roleFromProfile(
  Map<String, dynamic>? profile, {
  bool isAdmin = false,
}) {
  if (isAdmin) return UserRole.admin;
  if (profile?['is_verified_professor'] == true) return UserRole.professor;
  return UserRole.member;
}

/// A compact pill badge showing the user's role.
class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key, required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final (label, icon, textColor, bgColor, borderColor) = switch (role) {
      UserRole.admin => (
        'Admin',
        Icons.admin_panel_settings_outlined,
        const Color(0xFF7C3AED),
        const Color(0xFFF5F3FF),
        const Color(0xFFDDD6FE),
      ),
      UserRole.professor => (
        'Professor',
        Icons.verified_outlined,
        AppColors.successDark,
        AppColors.successLight,
        const Color(0xFF6EE7B7),
      ),
      UserRole.member => (
        'Member',
        Icons.person_outline,
        AppColors.textMuted,
        AppColors.surfaceLight,
        AppColors.border,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
