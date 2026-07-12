import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';

class ProfileMenuTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;
  final Widget? trailing;
  final Color? iconColor;

  const ProfileMenuTile({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
    this.trailing,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final defaultColor = isDestructive ? context.colorScheme.error : context.colorScheme.primary;
    final color = iconColor ?? defaultColor;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isDestructive ? context.colorScheme.error : Colors.black,
        ),
      ),
      trailing: trailing ?? Icon(
        Icons.chevron_right,
        color: context.colorScheme.onSurface.withValues(alpha: 0.3),
      ),
      onTap: onTap,
    );
  }
}
