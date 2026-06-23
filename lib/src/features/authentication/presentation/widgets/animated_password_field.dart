import 'package:flutter/material.dart';

class AnimatedPasswordField extends StatelessWidget {
  final Animation<double> animation;
  final TextEditingController controller;

  const AnimatedPasswordField({
    super.key,
    required this.animation,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Align(
            alignment: Alignment.topCenter,
            heightFactor: animation.value,
            child: FractionalTranslation(
              translation: Offset(0, animation.value - 1.0),
              child: child,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  left: 4.0,
                  bottom: 8.0,
                  top: 4.0,
                ),
                child: Text(
                  'Account found! Please enter your password.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                obscureText: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
