import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:budgetti/core/providers/providers.dart';

/// Frosted glass container. Respects the global `glass` toggle from
/// [themeSettingsProvider]. When disabled, renders a plain translucent surface
/// so callers get consistent shape/padding without blur cost.
class GlassContainer extends ConsumerWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final double blurSigma;
  final double opacity;
  final Color? tint;
  final Border? border;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.padding,
    this.blurSigma = 12,
    this.opacity = 0.12,
    this.tint,
    this.border,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glassEnabled = ref.watch(
      themeSettingsProvider.select((s) => s.glass),
    );
    final scheme = Theme.of(context).colorScheme;
    final bg = (tint ?? scheme.surfaceContainerHigh)
        .withValues(alpha: glassEnabled ? opacity : 1.0);

    final decoratedChild = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: borderRadius,
        border: border ??
            (glassEnabled
                ? Border.all(color: Colors.white.withValues(alpha: 0.15))
                : null),
      ),
      child: child,
    );

    if (!glassEnabled) return decoratedChild;

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: decoratedChild,
      ),
    );
  }
}
