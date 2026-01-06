import 'package:flutter/material.dart';

class BranchAnimationWrapper extends StatefulWidget {
  final int currentIndex;
  final Widget child;

  const BranchAnimationWrapper({
    super.key,
    required this.currentIndex,
    required this.child,
  });

  @override
  State<BranchAnimationWrapper> createState() => _BranchAnimationWrapperState();
}

class _BranchAnimationWrapperState extends State<BranchAnimationWrapper> {
  int _previousIndex = 0;

  @override
  void didUpdateWidget(BranchAnimationWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _previousIndex = oldWidget.currentIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isForward = widget.currentIndex >= _previousIndex;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      transitionBuilder: (Widget child, Animation<double> animation) {
        // We use the child's key to determine if it's the incoming or outgoing widget
        // The child passed to AnimatedSwitcher here is actually the 'widget.child' 
        // which will have a different value key based on the branch index.
        final bool isIncoming = child.key == ValueKey(widget.currentIndex);
        
        Offset begin;
        if (isIncoming) {
          begin = isForward ? const Offset(1.0, 0.0) : const Offset(-1.0, 0.0);
        } else {
          begin = isForward ? const Offset(-1.0, 0.0) : const Offset(1.0, 0.0);
        }

        return RepaintBoundary(
          child: SlideTransition(
            position: animation.drive(
              Tween<Offset>(
                begin: begin,
                end: Offset.zero,
              ).chain(CurveTween(curve: Curves.easeOutCubic)),
            ),
            child: FadeTransition(opacity: animation, child: child,
            ),
          ),
        );
      },
      layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
        return Stack(
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      child: KeyedSubtree(
        key: ValueKey(widget.currentIndex),
        child: widget.child,
      ),
    );
  }
}
