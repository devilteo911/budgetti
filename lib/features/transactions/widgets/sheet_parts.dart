import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The pieces the transaction editors' bottom sheets share.

class SaveButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color onColor;

  /// Null while a save is in flight — the tap guard against double-booking.
  final VoidCallback? onTap;

  const SaveButton({
    super.key,
    required this.label,
    required this.color,
    required this.onColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 56,
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              color: onColor,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

class KeyboardSpacer extends StatelessWidget {
  const KeyboardSpacer({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SizedBox(height: bottomInset > 0 ? bottomInset : 32);
  }
}
