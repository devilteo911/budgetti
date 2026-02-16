import 'package:flutter/material.dart';
import 'package:budgetti/core/theme/app_theme.dart';

class ActiveFilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onDeleted;

  const ActiveFilterChip({
    super.key,
    required this.label,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InputChip(
        label: Text(label,
            style: const TextStyle(fontSize: 12, color: AppTheme.primaryGreen)),
        onDeleted: onDeleted,
        deleteIcon:
            const Icon(Icons.close, size: 14, color: AppTheme.primaryGreen),
        backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: AppTheme.primaryGreen.withOpacity(0.3)),
        ),
      ),
    );
  }
}
