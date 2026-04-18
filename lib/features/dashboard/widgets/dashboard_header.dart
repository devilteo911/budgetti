import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.bricolageGrotesque(
            color: scheme.onSurface,
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            height: 1.0,
          ),
          children: [
            const TextSpan(text: 'budgetti'),
            TextSpan(
              text: '.',
              style: TextStyle(color: scheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}
