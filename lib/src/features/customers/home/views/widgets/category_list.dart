import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';

class CategoryList extends StatelessWidget {
  const CategoryList({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildCategoryCard('Hair', Icons.cut_outlined, const Color(0xFFF3E5F5)),
        _buildCategoryCard(
          'Makeup',
          Icons.face_retouching_natural,
          const Color(0xFFE0F7FA),
        ),
        _buildCategoryCard(
          'Eyebrows',
          Icons.visibility_outlined,
          const Color(0xFFF1F8E9),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(String title, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: AppTheme.darkRed),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.darkRed,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
