import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tokens.dart';

/// Prominent Floating Action Button for adding income or expense.
class NummoFAB extends StatelessWidget {
  final VoidCallback onPressed;

  const NummoFAB({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FloatingActionButton.extended(
      onPressed: () {
        HapticFeedback.lightImpact();
        onPressed();
      },
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      icon: Icon(Icons.add_rounded, size: 24, color: colorScheme.onPrimary),
      label: Text(
        'Add Transaction',
        style: TextStyle(
          color: colorScheme.onPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
