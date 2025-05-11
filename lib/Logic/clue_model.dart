// Flutter imports
import 'dart:math';

// ========== Clue ========== //

class Clue {
  // ===== Class variables ===== //

  final String direction;
  final int lineIndex;
  final List<String> clueTexts;
  final List<Point<int>> blockStartCoords;
  final List<int> blockLengths;
  final List<String> blockSolutions;

  // ===== Class methods ===== //

  // Constructor
  Clue({
    required this.direction,
    required this.lineIndex,
    required this.clueTexts,
    required this.blockStartCoords,
    required this.blockLengths,
    required this.blockSolutions,
  });

  // Constructor from JSON
  factory Clue.fromJson(
    Map<String, dynamic> json,
    int gridDim,
    List<List<String>> solutionGrid,
  ) {
    String dir = json['direction'] as String;
    int jsonClueNum = int.parse(json['clue_number'] as String);
    int lineIdx = dir == "horizontal" ? jsonClueNum - 1 : gridDim - jsonClueNum;

    List<String> jsonClueTextsRaw = [];
    if (json['clues'] is List) {
      for (var clueEntry in (json['clues'] as List)) {
        if (clueEntry is Map) {
          clueEntry.forEach((key, value) {
            if (value is String) jsonClueTextsRaw.add(value);
          });
        }
      }
    }

    List<Point<int>> blockStartCoordsResult = [];
    List<int> blockLengthsResult = [];
    List<String> blockSolutionsResult = [];
    List<String> finalMatchedClueTexts = [];

    if (dir == "horizontal") {
      _processHorizontalClues(
        gridDim,
        lineIdx,
        solutionGrid,
        jsonClueTextsRaw,
        blockStartCoordsResult,
        blockLengthsResult,
        blockSolutionsResult,
        finalMatchedClueTexts,
      );
    } else {
      _processVerticalClues(
        gridDim,
        lineIdx,
        solutionGrid,
        jsonClueTextsRaw,
        blockStartCoordsResult,
        blockLengthsResult,
        blockSolutionsResult,
        finalMatchedClueTexts,
      );
    }

    return Clue(
      direction: dir,
      lineIndex: lineIdx,
      clueTexts: finalMatchedClueTexts,
      blockStartCoords: blockStartCoordsResult,
      blockLengths: blockLengthsResult,
      blockSolutions: blockSolutionsResult,
    );
  }

  // Process horizontal clues
  static void _processHorizontalClues(
    int gridDim,
    int lineIdx,
    List<List<String>> solutionGrid,
    List<String> jsonClueTextsRaw,
    List<Point<int>> blockStartCoordsResult,
    List<int> blockLengthsResult,
    List<String> blockSolutionsResult,
    List<String> finalMatchedClueTexts,
  ) {
    List<Map<String, dynamic>> foundBlocksRaw = [];
    int currentColScan = 0;

    while (currentColScan < gridDim) {
      if (solutionGrid[lineIdx][currentColScan] != "0") {
        int blockStartCol = currentColScan;
        String blockSol = "";

        while (currentColScan < gridDim &&
            solutionGrid[lineIdx][currentColScan] != "0") {
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

    foundBlocksRaw.sort(
      (a, b) => (b['startCoord'] as Point<int>).y.compareTo(
        (a['startCoord'] as Point<int>).y,
      ),
    );

    for (int i = 0; i < foundBlocksRaw.length; i++) {
      if (i < jsonClueTextsRaw.length) {
        final blockData = foundBlocksRaw[i];
        blockStartCoordsResult.add(blockData['startCoord'] as Point<int>);
        blockLengthsResult.add(blockData['length'] as int);
        blockSolutionsResult.add(blockData['solution'] as String);
        finalMatchedClueTexts.add(jsonClueTextsRaw[i]);
      } else {
        break;
      }
    }
  }

  // Process vertical clues
  static void _processVerticalClues(
    int gridDim,
    int lineIdx,
    List<List<String>> solutionGrid,
    List<String> jsonClueTextsRaw,
    List<Point<int>> blockStartCoordsResult,
    List<int> blockLengthsResult,
    List<String> blockSolutionsResult,
    List<String> finalMatchedClueTexts,
  ) {
    int currentBlockClueTextIndex = 0;
    int currentRow = 0;

    while (currentRow < gridDim) {
      if (solutionGrid[currentRow][lineIdx] != "0") {
        int blockStartRow = currentRow;
        String currentBlockSolution = "";

        while (currentRow < gridDim &&
            solutionGrid[currentRow][lineIdx] != "0") {
          currentBlockSolution += solutionGrid[currentRow][lineIdx];
          currentRow++;
        }

        if (currentBlockSolution.length > 1 &&
            currentBlockClueTextIndex < jsonClueTextsRaw.length) {
          blockStartCoordsResult.add(Point(blockStartRow, lineIdx));
          blockLengthsResult.add(currentBlockSolution.length);
          blockSolutionsResult.add(currentBlockSolution);
          finalMatchedClueTexts.add(
            jsonClueTextsRaw[currentBlockClueTextIndex],
          );
          currentBlockClueTextIndex++;
        }
      } else {
        currentRow++;
      }
    }
  }
}
