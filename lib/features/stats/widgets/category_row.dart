import 'package:budgetti/models/category.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class CategoryRow extends StatelessWidget {
  final int rank;
  final Category category;
  final double amount;
  final double total;
  final NumberFormat currencyFormatter;
  final VoidCallback onTap;

  const CategoryRow({
    super.key,
    required this.rank,
    required this.category,
    required this.amount,
    required this.total,
    required this.currencyFormatter,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final catColor = Color(category.colorHex);
    final pct = total > 0 ? (amount / total * 100) : 0.0;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 34,
              decoration: BoxDecoration(
                color: catColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 14),
            SizedBox(
              width: 26,
              child: Text(
                rank.toString().padLeft(2, '0'),
                style: GoogleFonts.jetBrainsMono(
                  color: scheme.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              IconData(category.iconCode, fontFamily: 'MaterialIcons'),
              color: catColor,
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${pct.toStringAsFixed(1)}% of total',
                    style: GoogleFonts.jetBrainsMono(
                      color: scheme.onSurfaceVariant,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              currencyFormatter.format(amount),
              style: GoogleFonts.jetBrainsMono(
                color: scheme.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
