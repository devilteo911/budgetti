import 'package:flutter/material.dart';

import 'package:budgetti/core/theme/glass.dart';

/// GitHub-Store-inspired rounded surface card.
/// Use for summary tiles, list items, and grouped containers.
class ExpressiveCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final bool glass;

  const ExpressiveCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
    this.onTap,
    this.glass = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final br = BorderRadius.circular(radius);

    final body = glass
        ? GlassContainer(
            borderRadius: br,
            padding: padding,
            tint: scheme.surfaceContainerHigh,
            child: child,
          )
        : Container(
            padding: padding,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: br,
            ),
            child: child,
          );

    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: br,
        child: body,
      ),
    );
  }
}
