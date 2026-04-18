import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CarouselCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final Widget child;
  final VoidCallback? onLongPress;

  const CarouselCard({
    super.key,
    required this.icon,
    required this.label,
    required this.child,
    this.trailing,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(
            top: BorderSide(color: scheme.outline.withValues(alpha: 0.12), width: 1),
            bottom: BorderSide(color: scheme.outline.withValues(alpha: 0.12), width: 1),
            left: BorderSide(color: scheme.outline.withValues(alpha: 0.12), width: 1),
            right: BorderSide(color: scheme.outline.withValues(alpha: 0.12), width: 1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 11, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.jetBrainsMono(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.8,
                      fontSize: 10,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
