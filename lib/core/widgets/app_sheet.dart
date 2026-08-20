import 'package:flutter/material.dart';

/// Every modal bottom sheet in the app goes through here.
///
/// The call sites each re-specified `backgroundColor` and a top radius — at
/// three different radii, none of them the one `bottomSheetTheme` declares —
/// and half of them forgot `useRootNavigator`, which lets the shell's bottom
/// nav bar paint over the sheet. Both are settled here; only genuinely
/// per-sheet behaviour stays a parameter.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,

  /// Let the sheet grow past half the screen — forms and long lists.
  bool isScrollControlled = false,

  /// The theme's drag pill. Sheets that draw their own must leave this off.
  bool showDragHandle = false,
  BoxConstraints? constraints,
  bool useSafeArea = false,
}) =>
    showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: isScrollControlled,
      showDragHandle: showDragHandle,
      constraints: constraints,
      useSafeArea: useSafeArea,
      builder: builder,
    );
