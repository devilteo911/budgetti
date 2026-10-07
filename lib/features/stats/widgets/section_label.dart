import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SectionLabel extends StatelessWidget {
  final String text;
  final int? count;

  const SectionLabel({super.key, required this.text, this.count});

  // The rule between label and count is never squeezed below this: a label that
  // leaves less wraps instead (a long title, or a large system font).
  static const _minRule = 24.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textStyle = GoogleFonts.jetBrainsMono(
      color: scheme.onSurfaceVariant,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
    );
    // A count, not a code — zero-padding made "7 movements" read as "07".
    final countText = count?.toString();
    final countStyle = textStyle.copyWith(fontWeight: FontWeight.w600);

    double width(String s, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: s, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      final w = painter.width;
      painter.dispose();
      return w;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
      child: LayoutBuilder(
        builder: (context, box) {
          final label = Text(text, style: textStyle);
          final fits = width(text, textStyle) +
                  10 + _minRule +
                  (countText == null ? 0 : 10 + width(countText, countStyle)) <=
              box.maxWidth;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ponytail: no rule on a wrapped label, one hairline is not worth a
              // second layout pass.
              if (fits) label else Expanded(child: label),
              if (fits) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 1,
                    color: scheme.outlineVariant.withValues(alpha: 0.25),
                  ),
                ),
              ],
              if (countText != null) ...[
                const SizedBox(width: 10),
                Text(countText, style: countStyle),
              ],
            ],
          );
        },
      ),
    );
  }
}
