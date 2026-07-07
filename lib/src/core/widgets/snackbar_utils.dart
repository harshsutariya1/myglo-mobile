import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

extension SnackBarExtension on BuildContext {
  void showAppSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).clearSnackBars();
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: colorScheme.surface,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: colorScheme.surface,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? colorScheme.secondary : colorScheme.onSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        duration: const Duration(seconds: 4),
        elevation: 0,
      ),
    );
  }
}
