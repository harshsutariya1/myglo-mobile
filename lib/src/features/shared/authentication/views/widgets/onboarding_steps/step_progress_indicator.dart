import 'package:flutter/material.dart';
import '../../../../../../core/theme/app_theme.dart';

class StepProgressIndicator extends StatelessWidget {
  final int totalSteps;
  final int currentStep;

  const StepProgressIndicator({
    super.key,
    required this.totalSteps,
    required this.currentStep,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (index) {
        final isActive = index == currentStep;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          height: 8,
          width: isActive ? 16 : 8,
          decoration: BoxDecoration(
            color: isActive
                ? context.colorScheme.tertiary
                : context.colorScheme.onSurface.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
