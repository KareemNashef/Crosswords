import 'package:flutter/material.dart';

class PlayerScoreRow extends StatelessWidget {
  final String name;
  final int score;
  final bool isCurrent;
  final bool isMe;

  const PlayerScoreRow({
    super.key,
    required this.name,
    required this.score,
    required this.isCurrent,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurfaceColor = theme.colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: BoxDecoration(
        color: isCurrent ? theme.colorScheme.primary.withOpacity(0.25) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 2)
              ]
            : [],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(name, style: TextStyle(color: onSurfaceColor, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
              if (isMe) Text(' (أنت)', style: TextStyle(color: onSurfaceColor.withOpacity(0.7), fontSize: 12)),
            ],
          ),
          Text('$score', style: TextStyle(color: onSurfaceColor, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}