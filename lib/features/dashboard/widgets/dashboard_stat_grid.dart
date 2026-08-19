import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:budgetti/core/l10n.dart';
import 'package:budgetti/core/providers/providers.dart';

class DashboardStatGrid extends ConsumerWidget {
  const DashboardStatGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final stats = ref.watch(dashboardStatsProvider).value;
    final income = stats?.monthlyIncome ?? 0;
    final expense = stats?.monthlyExpenses ?? 0;
    final net = income - expense;

    final border = BorderSide(color: scheme.outline.withValues(alpha: 0.12));

    return Container(
      foregroundDecoration: BoxDecoration(
        border: Border.fromBorderSide(border),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _Cell(label: context.l10n.dashStatIn.toUpperCase(), value: _compact(income), color: scheme.primary, border: border),
            _Cell(label: context.l10n.dashStatOut.toUpperCase(), value: _compact(-expense), color: const Color(0xFFFF5C6C), border: border),
            _Cell(label: context.l10n.dashStatNet.toUpperCase(), value: _compact(net), color: scheme.onSurface, border: BorderSide.none),
          ],
        ),
      ),
    );
  }

  static String _compact(double n) {
    final abs = n.abs();
    final sign = n < 0 ? '−' : (n > 0 ? '+' : '');
    if (abs >= 1000) {
      return '$sign${(abs / 1000).toStringAsFixed(abs >= 10000 ? 0 : 1)}k';
    }
    return '$sign${abs.toStringAsFixed(0)}';
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.label,
    required this.value,
    required this.color,
    required this.border,
  });

  final String label;
  final String value;
  final Color color;
  final BorderSide border;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        decoration: BoxDecoration(border: Border(right: border)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.jetBrainsMono(
                color: scheme.onSurfaceVariant,
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.bricolageGrotesque(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
