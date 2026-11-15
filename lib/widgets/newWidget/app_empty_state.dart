// lib/widgets/newWidget/app_empty_state.dart
//
// Empty-state message for lists (Messages, Notifications). Uses plain Text with
// explicit colors, so it always shows, and it fills the space it is given.
import 'package:flutter/material.dart';

class AppEmptyState extends StatelessWidget {
  const AppEmptyState(this.title, {super.key, required this.subTitle});

  final String title;
  final String subTitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              subTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xff657786),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
