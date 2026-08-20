import 'package:flutter/material.dart';

import 'package:budgetti/core/l10n.dart';

/// Wraps a form modal so that dismissing it with unsaved edits asks first.
///
/// The sheets are dismissed by a swipe, a barrier tap or the system back
/// gesture as readily as by the Cancel button, and every one of them dropped a
/// half-typed form silently.
///
/// [isDirty] is a callback rather than a value because it is read at pop time:
/// the modal can compare against whatever snapshot it took when it opened
/// without having to rebuild on every keystroke.
class DiscardGuard extends StatelessWidget {
  const DiscardGuard({super.key, required this.isDirty, required this.child});

  final bool Function() isDirty;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Evaluated on every build, so a clean form still pops instantly.
      canPop: !isDirty(),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await confirmDiscard(context)) navigator.pop();
      },
      child: child,
    );
  }
}

/// "Throw away what you typed?" — true if the user says yes.
Future<bool> confirmDiscard(BuildContext context) async {
  final l10n = context.l10n;
  final discard = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.commonDiscardTitle),
      content: Text(l10n.commonDiscardBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.commonKeepEditing),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(ctx).colorScheme.error,
          ),
          child: Text(l10n.commonDiscard),
        ),
      ],
    ),
  );
  return discard ?? false;
}
