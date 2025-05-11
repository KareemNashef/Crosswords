// Flutter imports
import 'package:flutter/material.dart';

// Local imports
import 'package:crosswords/Logic/clue_model.dart';

// ========== Cell Model ========== //

class CellModel {
  // ===== Class variables ===== //

  String enteredChar = '';
  final String solutionChar;
  final bool isBlackSquare;
  Color displayColor;
  final int row;
  final int col;
  String? displayNumber;
  Clue? acrossClue;
  int? acrossBlockIndex;
  Clue? downClue;
  int? downBlockIndex;
  Rect originalRect = Rect.zero;
  int animationIndex = 0;

  // ===== Class methods ===== //

  // Constructor
  CellModel({
    required this.solutionChar,
    required this.isBlackSquare,
    required this.displayColor,
    required this.row,
    required this.col,
    this.displayNumber,
    this.acrossClue,
    this.acrossBlockIndex,
    this.downClue,
    this.downBlockIndex,
  });

  // Check if current entered char is correct
  bool get isCurrentCharCorrect =>
      !isBlackSquare && enteredChar.isNotEmpty && enteredChar == solutionChar;

  // Get word solution
  String? getWordSolution(String direction) {
    if (direction == "horizontal" &&
        acrossClue != null &&
        acrossBlockIndex != null) {
      return acrossClue!.blockSolutions[acrossBlockIndex!];
    } else if (direction == "vertical" &&
        downClue != null &&
        downBlockIndex != null) {
      return downClue!.blockSolutions[downBlockIndex!];
    }
    return null;
  }
}
