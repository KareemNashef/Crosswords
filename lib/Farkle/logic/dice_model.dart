// lib/Farkle/logic/dice_model.dart

import 'package:flutter/material.dart';
import 'dart:math';

/// Abstract base class for any type of die in the game.
abstract class BaseDice {
  // Add a generative constructor. This allows other classes to extend BaseDice.
  BaseDice();

  // Visual properties for the die.
  Color get primaryColor;
  Gradient? get gradient;
  String get typeId; // To identify the dice type for storage

  // The current face value of the die.
  int value = 1;

  /// Rolls the die and returns the new value.
  int roll();

  // Factory to create a dice from a string ID
  factory BaseDice.fromId(String id) {
    switch (id) {
      case 'lucky':
        return LuckyDice();
      case 'celestial':
        return CelestialDice();
      case 'shadow':
        return ShadowDice();
      case 'unstable':
        return UnstableDice();
      case 'standard':
      default:
        return StandardDice();
    }
  }
}

/// A standard 6-sided die with equal probabilities for each face.
class StandardDice extends BaseDice {
  final Random _random = Random();

  @override
  String get typeId => 'standard';

  @override
  Color get primaryColor => Colors.white;

  @override
  Gradient? get gradient => null; // No special gradient for standard dice.

  @override
  int roll() {
    value = _random.nextInt(6) + 1;
    return value;
  }
}

/// A "lucky" die with a higher chance of rolling scoring numbers.
class LuckyDice extends BaseDice {
  final Random _random = Random();

  @override
  String get typeId => 'lucky';

  @override
  Color get primaryColor => Colors.amber;

  @override
  Gradient? get gradient => RadialGradient(
    colors: [Colors.yellow.shade600, Colors.orange.shade900],
    center: Alignment.center,
    radius: 0.7,
  );

  @override
  int roll() {
    final List<int> weightedOutcomes = [1, 1, 2, 3, 4, 5, 5, 6];
    value = weightedOutcomes[_random.nextInt(weightedOutcomes.length)];
    return value;
  }
}

/// A predictable die that avoids certain numbers.
class CelestialDice extends BaseDice {
  final Random _random = Random();

  @override
  String get typeId => 'celestial';

  @override
  Color get primaryColor => Colors.lightBlueAccent;

  @override
  Gradient? get gradient => LinearGradient(
    colors: [Colors.lightBlue.shade100, Colors.grey.shade400],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  int roll() {
    // Can never roll a 3 or 4, making it more predictable.
    final List<int> outcomes = [1, 2, 5, 6];
    value = outcomes[_random.nextInt(outcomes.length)];
    return value;
  }
}

/// A die that favors middle numbers, good for building sets.
class ShadowDice extends BaseDice {
  final Random _random = Random();

  @override
  String get typeId => 'shadow';

  @override
  Color get primaryColor => Colors.deepPurple;

  @override
  Gradient? get gradient => RadialGradient(
    colors: [Colors.deepPurple.shade700, Colors.black],
    center: Alignment.center,
    radius: 0.8,
  );

  @override
  int roll() {
    // Higher chance of rolling non-scoring middle numbers
    final List<int> weightedOutcomes = [1, 2, 2, 3, 3, 4, 4, 5, 6];
    value = weightedOutcomes[_random.nextInt(weightedOutcomes.length)];
    return value;
  }
}

/// A chaotic die that can save a bad roll.
class UnstableDice extends BaseDice {
  final Random _random = Random();

  @override
  String get typeId => 'unstable';

  @override
  Color get primaryColor => Colors.redAccent;

  @override
  Gradient? get gradient => LinearGradient(
    colors: [Colors.red.shade900, Colors.orange.shade700],
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
  );

  @override
  int roll() {
    value = _random.nextInt(6) + 1;
    // 25% chance to "fix" a bad roll (2, 3, 4) into a good one
    if ([2, 3, 4].contains(value) && _random.nextInt(4) == 0) {
      value = [1, 6][_random.nextInt(2)];
    }
    return value;
  }
}