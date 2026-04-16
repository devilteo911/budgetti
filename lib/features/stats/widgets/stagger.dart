import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class Stagger extends StatelessWidget {
  final AnimationController controller;
  final double begin;
  final double end;
  final Widget child;

  const Stagger({
    super.key,
    required this.controller,
    required this.begin,
    required this.end,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: controller,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (context, _) {
        final v = curved.value.clamp(0.0, 1.0);
        return SliverOpacity(
          opacity: v,
          sliver: SliverTranslate(
            dy: (1 - v) * 14,
            sliver: child,
          ),
        );
      },
    );
  }
}

class SliverTranslate extends SingleChildRenderObjectWidget {
  final double dy;

  const SliverTranslate({super.key, required this.dy, required Widget sliver})
      : super(child: sliver);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderSliverTranslate(dy: dy);

  @override
  void updateRenderObject(
      BuildContext context, RenderSliverTranslate renderObject) {
    renderObject.dy = dy;
  }
}

class RenderSliverTranslate extends RenderProxySliver {
  double _dy;
  RenderSliverTranslate({required double dy}) : _dy = dy;

  set dy(double value) {
    if (_dy == value) return;
    _dy = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      context.paintChild(child!, offset + Offset(0, _dy));
    }
  }
}
