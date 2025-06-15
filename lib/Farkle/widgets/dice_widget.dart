// lib/Farkle/widgets/dice_widget.dart

import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import '../logic/dice_model.dart'; // Import the dice model

class DiceWidget extends StatelessWidget {
  final BaseDice dice; // Pass the entire dice object
  final bool isSelected, isKept;
  final bool isRolling;
  final Animation<double> animation;
  final VoidCallback? onTap;

  const DiceWidget({
    super.key,
    required this.dice, // Updated parameter
    required this.isSelected,
    required this.isKept,
    required this.isRolling,
    required this.animation,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    Color borderColor = isKept
        ? theme.secondary
        : (isSelected ? theme.primary : Colors.white.withOpacity(0.2));
    
    final bool shouldAnimate = isRolling && !isKept;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final angle = shouldAnimate ? (animation.value * (pi * 4)) : 0;
        // Use the dice's value, but show random numbers during animation
        final displayValue = shouldAnimate ? (Random().nextInt(6) + 1) : dice.value;

        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateX(angle * 1.2)
            ..rotateY(angle * 1.2),
          alignment: FractionalOffset.center,
          child: GestureDetector(
            onTap: onTap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    // FIX: Use the dice's gradient if it exists
                    gradient: dice.gradient,
                    color: isKept
                        ? theme.secondaryContainer.withOpacity(0.5)
                        : theme.surface.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor, width: 2.5),
                    boxShadow: isSelected ? [
                      BoxShadow(color: theme.primary.withOpacity(0.7), blurRadius: 10, spreadRadius: 1),
                    ] : [],
                  ),
                  child: _DiceFace(value: displayValue),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DiceFace extends StatelessWidget {
  final int value;
  const _DiceFace({required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GridView.count(
        crossAxisCount: 3,
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(9, (i) => _dotVisibility[value - 1][i] ? const _DiceDot() : Container()),
      ),
    );
  }
}

class _DiceDot extends StatelessWidget {
  const _DiceDot();
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.onSurface,
          boxShadow: [
             BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 2)
          ]
      ),
    );
  }
}

const List<List<bool>> _dotVisibility = [
  [false, false, false, false, true, false, false, false, false], // 1
  [true, false, false, false, false, false, false, false, true],  // 2
  [true, false, false, false, true, false, false, false, true],  // 3
  [true, false, true, false, false, false, true, false, true],   // 4
  [true, false, true, false, true, false, true, false, true],   // 5
  [true, false, true, true, false, true, true, false, true],    // 6
];