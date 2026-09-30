import 'package:flutter/material.dart';

/// A message drawn INSIDE a bottom sheet, above its action button.
///
/// Not a SnackBar: a modal sheet opened on the root navigator sits over the
/// root ScaffoldMessenger, so a SnackBar raised while the sheet is open is drawn
/// behind it and the owner only sees the sheet refusing to close. Empty when
/// [message] is null. A live region, so a screen reader announces it.
class InlineSheetMessage extends StatelessWidget {
  const InlineSheetMessage(this.message, {super.key, this.isError = true});

  final String? message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final text = message;
    if (text == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Semantics(
        liveRegion: true,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isError ? scheme.error : scheme.primary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
