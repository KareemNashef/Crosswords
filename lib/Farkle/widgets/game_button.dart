import 'package:flutter/material.dart';

class GameButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isLarge;

  const GameButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isPrimary = false,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: isPrimary ? Colors.white : Theme.of(context).colorScheme.primary,
        backgroundColor: isPrimary
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.primaryContainer.withOpacity(0.7),
        padding: EdgeInsets.symmetric(
            horizontal: isLarge ? 40 : 20, vertical: isLarge ? 16 : 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        textStyle: TextStyle(
            fontSize: isLarge ? 20 : 14, fontWeight: FontWeight.bold),
        disabledForegroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.38),
        disabledBackgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.12),
      ),
      child: Text(label),
    );
  }
}