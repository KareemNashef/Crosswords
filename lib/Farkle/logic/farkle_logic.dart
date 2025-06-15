import 'dart:math';

/// Calculates the score for a given list of dice values.
/// Includes new rules for 5-dice straights.
int calculateScore(List<int> dice) {
  if (dice.isEmpty) return 0;

  final counts = <int, int>{};
  for (final die in dice) {
    counts[die] = (counts[die] ?? 0) + 1;
  }
  final uniqueFaces = counts.keys.toList()..sort();

  // Check for special combinations that use all dice in the selection
  if (dice.length == 6) {
    if (uniqueFaces.length == 6) return 1500; // 1-6 Straight
    if (counts.values.where((c) => c == 2).length == 3) return 1500; // 3 Pairs
    if (counts.values.contains(4) && counts.values.contains(2)) return 1500; // 4-of-a-kind + Pair
    if (counts.values.where((c) => c == 3).length == 2) return 2500; // Two 3-of-a-kinds
  }
  
  if (dice.length == 5 && uniqueFaces.length == 5) {
      if (!uniqueFaces.contains(6)) return 500; // 1-2-3-4-5 Straight
      if (!uniqueFaces.contains(1)) return 750; // 2-3-4-5-6 Straight
  }

  // Standard greedy scoring for N-of-a-kind and individual 1s and 5s
  int score = 0;
  final tempCounts = Map<int, int>.from(counts);

  tempCounts.forEach((face, count) {
    if (count >= 3) {
      // Score for 3, 4, 5, or 6 of a kind.
      score += (face == 1 ? 1000 : face * 100) * (1 << (count - 3));
      tempCounts[face] = 0; // Consume these dice so they aren't scored again
    }
  });

  // Score remaining 1s and 5s
  score += (tempCounts[1] ?? 0) * 100;
  score += (tempCounts[5] ?? 0) * 50;

  return score;
}

/// Checks if every die in a selection is part of a valid scoring group.
/// For example, {1, 2, 2} is invalid because the two 2s don't score.
bool isSelectionValid(List<int> dice) {
  if (dice.isEmpty) return true;

  // Check for special combinations that use all dice by definition.
  final counts = <int, int>{};
  for (final die in dice) { counts[die] = (counts[die] ?? 0) + 1; }
  
  if (dice.length >= 5) {
      if (calculateScore(dice) > 0) return true;
  }
  
  int usedDiceCount = 0;
  final tempCounts = Map<int, int>.from(counts);
  
  // Count dice used in N-of-a-kind groups
  tempCounts.forEach((face, count) {
    if (count >= 3) {
      usedDiceCount += count;
    }
  });
  
  // Count dice used as scoring singles (if they weren't in a larger group)
  if ((tempCounts[1] ?? 0) < 3) {
    usedDiceCount += (tempCounts[1] ?? 0);
  }
  if ((tempCounts[5] ?? 0) < 3) {
    usedDiceCount += (tempCounts[5] ?? 0);
  }
  
  // The selection is valid only if every die is accounted for.
  return usedDiceCount == dice.length;
}

/// Checks if there are any scorable dice on the table.
bool hasScoringDiceOnTable(List<int> availableDice) {
  if (availableDice.isEmpty) return false;

  Map<int, int> counts = {};
  for (int die in availableDice) {
    counts[die] = (counts[die] ?? 0) + 1;
  }

  // Check for any 3-of-a-kind or better
  if (counts.values.any((c) => c >= 3)) return true;
  // Check for single 1s or 5s
  if (counts.containsKey(1) || counts.containsKey(5)) return true;
  
  // Check for full-table special combinations
  if (availableDice.length == 6) {
      availableDice.sort();
      final uniqueFaces = counts.keys.toList();
      if (uniqueFaces.length == 6) return true; // Straight
      if (counts.values.where((c) => c == 2).length == 3) return true; // 3 pairs
  }

  // A full check for subset straights (like 1-2-3-4-5) is complex and often not
  // needed for a basic Farkle check. The above checks cover most scenarios.
  return false;
}