// Flutter imports
import 'package:flutter/material.dart';
import 'dart:math' show Point; // For Point

// ========== Cell Model ========== //
class CellModel {
  String enteredChar = '';
  final String solutionChar; // Full solution for this specific cell
  final bool isBlackSquare;
  Color displayColor;
  final int row; // 0-based
  final int col; // 0-based
  String? displayNumber; // Visual number in the cell (1, 2, 3...)

  // Direct reference to the clue object and the specific block within that clue
  Clue? acrossClue;
  int? acrossBlockIndex; // Index into acrossClue.clueTexts, .blockSolutions etc.

  Clue? downClue;
  int? downBlockIndex;

  // For animation
  Rect originalRect = Rect.zero;
  int animationIndex = 0; // Index within the animated word (0, 1, 2...)

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

  // Is this cell's entered char correct for its specific solutionChar?
  bool get isCurrentCharCorrect => !isBlackSquare && enteredChar.isNotEmpty && enteredChar == solutionChar;

  // Get the full solution for the word this cell is part of, if selected
  String? getWordSolution(String direction) {
    if (direction == "horizontal" && acrossClue != null && acrossBlockIndex != null) {
      return acrossClue!.blockSolutions[acrossBlockIndex!];
    } else if (direction == "vertical" && downClue != null && downBlockIndex != null) {
      return downClue!.blockSolutions[downBlockIndex!];
    }
    return null;
  }
}

// ========== Clue Model (Heavily Revised) ========== //
class Clue {
  final String direction; // "horizontal" or "vertical"
  final int lineIndex;  // 0-based row index (if horizontal) or col index (if vertical)

  // These lists correspond to each block of non-black cells in the lineIndex
  final List<String> clueTexts;         // The actual clue strings from "clue_X)"
  final List<Point<int>> blockStartCoords; // For horizontal: (row, startCol). For vertical: (startRow, col)
  final List<int> blockLengths;
  final List<String> blockSolutions;    // The full solution string for each block

  Clue({
    required this.direction,
    required this.lineIndex,
    required this.clueTexts,
    required this.blockStartCoords,
    required this.blockLengths,
    required this.blockSolutions,
  });

  // fromJson will need to be intelligent to parse blocks from the solutionGrid
  factory Clue.fromJson(Map<String, dynamic> json, int gridDim, List<List<String>> solutionGrid) {
    String dir = json['direction'] as String;
  int jsonClueNum = int.parse(json['clue_number'] as String);
  int lineIdx; // This will be the 0-based index used internally

  if (dir == "horizontal") {
    lineIdx = jsonClueNum - 1; // Row index is straightforward
  } else { // Vertical
    // If JSON "1" means leftmost column on RTL display, it's gridDim - 1
    // If JSON "gridDim" means rightmost column on RTL display, it's 0
    // So, for a 1-based jsonClueNum (1 to gridDim, left to right on screen):
    // jsonClueNum = 1 (leftmost) -> lineIdx = gridDim - 1
    // jsonClueNum = gridDim (rightmost) -> lineIdx = 0
    lineIdx = gridDim - jsonClueNum;
  }
  
    List<String> jsonClueTextsRaw = []; // Raw texts from JSON (e.g., for clue_1, clue_2)
    if (json['clues'] is List) {
      (json['clues'] as List).forEach((clueEntry) {
        if (clueEntry is Map) {
          clueEntry.forEach((key, value) {
            if (value is String) {
              jsonClueTextsRaw.add(value);
            }
          });
        }
      });
    }

    List<Point<int>> blockStartCoordsResult = [];
    List<int> blockLengthsResult = [];
    List<String> blockSolutionsResult = [];
    List<String> finalMatchedClueTexts = []; // Clue texts that correspond to a found block

    if (dir == "horizontal") {
      // Step 1: Find all horizontal blocks with length > 1 in the current row (lineIdx)
      List<Map<String, dynamic>> foundBlocksRaw = [];
      int currentColScan = 0;
      while (currentColScan < gridDim) {
        if (solutionGrid[lineIdx][currentColScan] != "0") {
          int blockStartCol = currentColScan;
          String blockSol = "";
          while (currentColScan < gridDim && solutionGrid[lineIdx][currentColScan] != "0") {
            blockSol += solutionGrid[lineIdx][currentColScan];
            currentColScan++;
          }
          if (blockSol.length > 1) {
            foundBlocksRaw.add({
              'startCoord': Point(lineIdx, blockStartCol),
              'length': blockSol.length,
              'solution': blockSol,
            });
          }
        } else {
          currentColScan++;
        }
      }

      // Step 2: Sort these found blocks from right to left (descending start column)
      // This aligns with RTL: the rightmost block is the "first" for clue assignment.
      foundBlocksRaw.sort((a, b) =>
          (b['startCoord'] as Point<int>).y.compareTo((a['startCoord'] as Point<int>).y)
      );

      // Step 3: Assign JSON clue texts (jsonClueTextsRaw[0] for "clue_1", etc.)
      // to these RTL-ordered blocks.
      for (int i = 0; i < foundBlocksRaw.length; i++) {
        if (i < jsonClueTextsRaw.length) { // If a JSON clue text exists for this (i-th RTL) block
          final blockData = foundBlocksRaw[i];
          blockStartCoordsResult.add(blockData['startCoord'] as Point<int>);
          blockLengthsResult.add(blockData['length'] as int);
          blockSolutionsResult.add(blockData['solution'] as String);
          finalMatchedClueTexts.add(jsonClueTextsRaw[i]); // Assign the corresponding clue text
        } else {
          break; // No more JSON clue texts for the remaining blocks
        }
      }
    } else { // Vertical (top-to-bottom is standard for "clue_1", "clue_2")
      int currentBlockClueTextIndex = 0;
      int currentRow = 0;
      while (currentRow < gridDim) {
        if (solutionGrid[currentRow][lineIdx] != "0") {
          int blockStartRow = currentRow;
          String currentBlockSolution = "";
          while (currentRow < gridDim && solutionGrid[currentRow][lineIdx] != "0") {
            currentBlockSolution += solutionGrid[currentRow][lineIdx];
            currentRow++;
          }
          if (currentBlockSolution.length > 1 && currentBlockClueTextIndex < jsonClueTextsRaw.length) {
            blockStartCoordsResult.add(Point(blockStartRow, lineIdx));
            blockLengthsResult.add(currentBlockSolution.length);
            blockSolutionsResult.add(currentBlockSolution);
            finalMatchedClueTexts.add(jsonClueTextsRaw[currentBlockClueTextIndex]);
            currentBlockClueTextIndex++;
          }
        } else {
          currentRow++;
        }
      }
    }

    return Clue(
      direction: dir,
      lineIndex: lineIdx,
      clueTexts: finalMatchedClueTexts, // Use the texts that were successfully matched
      blockStartCoords: blockStartCoordsResult,
      blockLengths: blockLengthsResult,
      blockSolutions: blockSolutionsResult,
    );
  }
}