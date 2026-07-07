import 'package:flutter/material.dart';

class HomeSearchBar extends StatelessWidget {
  const HomeSearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(32),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: const TextField(
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search, color: Colors.black54),
                hintText: 'What are you looking for?',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.black38),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Icon(Icons.location_on_outlined, color: Colors.black54),
      ],
    );
  }
}
