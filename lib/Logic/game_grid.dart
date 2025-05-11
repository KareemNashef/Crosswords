// Flutter imports
import 'package:flutter/material.dart';
import 'dart:math' show Point;
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

// Local imports
import 'package:crosswords/Logic/puzzle_models.dart';
import 'package:crosswords/Logic/animated_popup.dart';

class GameGrid extends StatefulWidget {
  final String puzzleNumber;
  GameGrid({super.key, required this.puzzleNumber});
  @override
  GameGridState createState() => GameGridState();
}

class GameGridState extends State<GameGrid> with TickerProviderStateMixin {
  int gridSize = 15;
  bool isAnimating = false;
  bool _isLoading = true;
  bool _colorsInitialized = false;

  late AnimationController animationController;

  // Store the specific Clue object and block index for the currently selected word
  Clue? activeClue;
  int? activeBlockIndexInClue;
  String? activeDirection; // "horizontal" or "vertical"

  List<CellModel> cellsToAnimate = [];
  List<List<CellModel>> gridCellData = [];
  List<Clue> allParsedClues = []; // Stores Clue objects parsed with block info
  List<List<GlobalKey>> gridKeys = [];

  late Color _initialCellColor;
  late Color _correctCellColor;
  late Color _errorCellColor;

  @override
  void initState() {
    super.initState();
    animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadPuzzleData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_colorsInitialized) {
      _initialCellColor = Theme.of(context).colorScheme.secondaryContainer;
      _correctCellColor = Theme.of(context).colorScheme.primaryContainer;
      _errorCellColor = Theme.of(context).colorScheme.errorContainer;
      _colorsInitialized = true;
      if (!_isLoading) {
        _reapplyInitialColors();
        if (mounted) setState(() {});
      }
    }
  }

  void _reapplyInitialColors() {
    if (!_colorsInitialized || gridCellData.isEmpty) return;
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        final cell = gridCellData[r][c];
        if (cell.isBlackSquare) {
          cell.displayColor = Colors.black;
        } else if (cell.enteredChar.isEmpty) {
          cell.displayColor = _initialCellColor;
        } else {
          // Color based on correctness is already set during input
        }
      }
    }
  }

  Future<void> _loadPuzzleData() async {
    try {
      final String solutionJsonString = await rootBundle.loadString(
        'assets/Puzzles/puzzle_${widget.puzzleNumber}_solution.json',
      );
      final List<dynamic> decodedSolutionsRaw = json.decode(solutionJsonString);
      final List<List<String>> solutionGrid =
          decodedSolutionsRaw.map((row) => List<String>.from(row)).toList();

      if (solutionGrid.isNotEmpty) {
        gridSize = solutionGrid.length;
      } else {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Initialize gridCellData first (without clue links yet)
      _initializeGridCells(solutionGrid);
      _initializeKeys();

      final String cluesJsonRawString = await rootBundle.loadString(
        'assets/Puzzles/puzzle_${widget.puzzleNumber}_clues.json',
      );
      final List<dynamic> decodedCluesJson = json.decode(cluesJsonRawString);

      allParsedClues.clear();
      for (var clueJsonEntry in decodedCluesJson) {
        if (clueJsonEntry is Map<String, dynamic>) {
          // Pass solutionGrid to Clue.fromJson to help it identify blocks
          Clue parsedClue = Clue.fromJson(
            clueJsonEntry,
            gridSize,
            solutionGrid,
          );
          if (parsedClue.blockSolutions.isNotEmpty) {
            // Only add if it found valid blocks
            allParsedClues.add(parsedClue);
          }
        }
      }

      _assignCluesToCells();

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_colorsInitialized) _reapplyInitialColors();
        });
      }
    } catch (e) {
      print("Error loading puzzle data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _initializeGridCells(List<List<String>> solutionGrid) {
    Color tempInitialColor =
        _colorsInitialized ? _initialCellColor : Colors.grey.shade300;
    gridCellData = List.generate(
      gridSize,
      (r) => List.generate(gridSize, (c) {
        final char = solutionGrid[r][c];
        final isBlack = char == "0";
        return CellModel(
          solutionChar: isBlack ? '' : char,
          isBlackSquare: isBlack,
          displayColor: isBlack ? Colors.black : tempInitialColor,
          row: r,
          col: c,
        );
      }),
    );
  }

  void _initializeKeys() {
    gridKeys = List.generate(
      gridSize,
      (r) => List.generate(gridSize, (c) => GlobalKey()),
    );
  }

  void _assignCluesToCells() {
    // Renamed
    // Clear any previous assignments
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        gridCellData[r][c].acrossClue = null;
        gridCellData[r][c].acrossBlockIndex = null;
        gridCellData[r][c].downClue = null;
        gridCellData[r][c].downBlockIndex = null;
        // gridCellData[r][c].displayNumber = null; // No longer needed or set
      }
    }

    for (final clue in allParsedClues) {
      for (
        int blockIdx = 0;
        blockIdx < clue.blockSolutions.length;
        blockIdx++
      ) {
        Point<int> startCoord = clue.blockStartCoords[blockIdx];
        int length = clue.blockLengths[blockIdx];

        for (int i = 0; i < length; i++) {
          CellModel currentCell;
          if (clue.direction == "horizontal") {
            currentCell =
                gridCellData[startCoord.x.toInt()][startCoord.y.toInt() + i];
            currentCell.acrossClue = clue;
            currentCell.acrossBlockIndex = blockIdx;
          } else {
            // vertical
            currentCell =
                gridCellData[startCoord.x.toInt() + i][startCoord.y.toInt()];
            currentCell.downClue = clue;
            currentCell.downBlockIndex = blockIdx;
          }
        }
      }
    }
  }

  Rect? _getCellRect(int row, int col) {
    if (row < 0 ||
        row >= gridSize ||
        col < 0 ||
        col >= gridSize ||
        gridKeys.isEmpty ||
        gridKeys[row].isEmpty ||
        gridKeys[row][col].currentContext == null) {
      return null;
    }
    final context = gridKeys[row][col].currentContext;
    if (context == null) return null;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final position = box.localToGlobal(Offset.zero);
    return Rect.fromLTWH(
      position.dx,
      position.dy,
      box.size.width,
      box.size.height,
    );
  }

  // In GameGridState class

  void _handleSwipe(int r, int c, String swipeGestureDirection) {
    if (isAnimating || gridCellData[r][c].isBlackSquare) return;

    CellModel swipedCell = gridCellData[r][c];
    activeClue = null;
    activeBlockIndexInClue = null;
    activeDirection = null;

    if (swipeGestureDirection == 'left' && swipedCell.acrossClue != null) {
      activeDirection = "horizontal";
      activeClue = swipedCell.acrossClue;
      activeBlockIndexInClue = swipedCell.acrossBlockIndex;
    } else if (swipeGestureDirection == 'down' && swipedCell.downClue != null) {
      activeDirection = "vertical";
      activeClue = swipedCell.downClue;
      activeBlockIndexInClue = swipedCell.downBlockIndex;
    }

    if (activeClue != null && activeBlockIndexInClue != null) {
      cellsToAnimate.clear(); // Clear before populating
      Point<int> startCoord =
          activeClue!.blockStartCoords[activeBlockIndexInClue!];
      int length = activeClue!.blockLengths[activeBlockIndexInClue!];

      if (activeDirection == "horizontal") {
        List<CellModel> physicalOrderCells = [];
        for (int i = 0; i < length; i++) {
          // Collect cells from grid data (leftmost part of word to rightmost part)
          CellModel cell =
              gridCellData[startCoord.x.toInt()][startCoord.y.toInt() + i];
          physicalOrderCells.add(cell);
        }

        // IF the main board visually shows "5 4 3 2 1" (RTL) for a word whose LTR data is "1 2 3 4 5",
        // AND we want the popup to also represent this as "5 4 3 2 1" (RTL) where TextField[0] is for '5',
        // THEN `cellsToAnimate` needs to be [CellFor5, CellFor4, ..., CellFor1].
        // `physicalOrderCells` is [CellFor1, CellFor2, ..., CellFor5] because grid data is LTR.
        // So, for RTL horizontal, we reverse `physicalOrderCells`.
        final bool isAppRTL =
            Localizations.localeOf(context).languageCode == 'ar';
        if (isAppRTL) {
          // Only reverse if the app is in RTL mode for horizontal words
          physicalOrderCells = physicalOrderCells.reversed.toList();
        }
        // Now, physicalOrderCells[0] is the CellModel for the char that should appear
        // rightmost in the popup (e.g., '5').

        for (int i = 0; i < physicalOrderCells.length; i++) {
          CellModel cell = physicalOrderCells[i];
          final rect = _getCellRect(cell.row, cell.col);
          if (rect != null) {
            cell.originalRect = rect;
            cell.animationIndex =
                i; // So cellsToAnimate[0].animationIndex = 0 (for '5')
            cellsToAnimate.add(cell);
          }
        }
      } else {
        // Vertical
        for (int i = 0; i < length; i++) {
          CellModel cellInWord =
              gridCellData[startCoord.x.toInt() + i][startCoord.y.toInt()];
          final rect = _getCellRect(cellInWord.row, cellInWord.col);
          if (rect != null) {
            cellInWord.originalRect = rect;
            cellInWord.animationIndex = i; // Topmost is 0
            cellsToAnimate.add(cellInWord);
          }
        }
      }

      if (cellsToAnimate.isNotEmpty) {
        _showAnimatedPopup();
      }
    }
  }

  void _showAnimatedPopup() {
    if (!_colorsInitialized ||
        activeClue == null ||
        activeBlockIndexInClue == null)
      return;

    setState(() => isAnimating = true);
    animationController.reset();
    animationController.forward();

    final String currentClueText =
        activeClue!.clueTexts[activeBlockIndexInClue!];
    final String currentWordSolution =
        activeClue!.blockSolutions[activeBlockIndexInClue!];

    showDialog(
      context: context,
      barrierDismissible: true, // Allow dismiss by tapping outside
      barrierColor: Colors.transparent,
      builder: (BuildContext context) {
        return AnimatedPopup(
          cellsToAnimate: cellsToAnimate,
          animationController: animationController,
          direction: activeDirection!,
          clueText: currentClueText, // Pass only the specific clue text
          wordSolution: currentWordSolution,
          initialCellColor: _initialCellColor,
          correctCellColor: _correctCellColor,
          errorCellColor: _errorCellColor,
          onSubmitOrDismiss: (Map<int, String> enteredCharsMap) {
            // Map from cell animIndex to char
            Navigator.of(context).pop(); // Dismiss popup
            // Apply changes to gridCellData
            for (final cell in cellsToAnimate) {
              String? enteredForThisCell = enteredCharsMap[cell.animationIndex];
              if (enteredForThisCell != null) {
                cell.enteredChar = enteredForThisCell;
                // Color is already set by AnimatedPopup's real-time feedback
                // but we can re-affirm it here if needed or if popup doesn't fully manage it
                if (cell.isCurrentCharCorrect) {
                  cell.displayColor = _correctCellColor;
                } else if (cell.enteredChar.isNotEmpty) {
                  // only mark error if something was entered
                  cell.displayColor = _errorCellColor;
                } else {
                  cell.displayColor =
                      _initialCellColor; // Back to initial if cleared
                }
              }
            }
          },
        );
      },
    ).then((_) {
      animationController.reverse().whenComplete(() {
        // Use whenComplete for safety
        if (mounted) {
          setState(() {
            isAnimating = false;
            // Ensure grid reflects final state of characters and colors
            // This re-renders the main grid with updated cell states
          });
        }
      });
    });
  }

  // Swipe detection (no major changes, ensure it covers the whole grid)
  Offset? _swipeStartPosition;
  int? _swipeCellRow;
  int? _swipeCellCol;

  void _onPanStart(DragStartDetails details, int row, int col) {
    // print("PanStart on $row, $col"); // Debugging
    if (isAnimating || gridCellData[row][col].isBlackSquare) return;
    _swipeStartPosition = details.globalPosition;
    _swipeCellRow = row;
    _swipeCellCol = col;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (isAnimating ||
        _swipeStartPosition == null ||
        _swipeCellRow == null ||
        _swipeCellCol == null)
      return;
    if (gridCellData[_swipeCellRow!][_swipeCellCol!].isBlackSquare) {
      _swipeStartPosition = null;
      return; // Reset if started on black somehow or became black
    }

    final dx = details.globalPosition.dx - _swipeStartPosition!.dx;
    final dy = details.globalPosition.dy - _swipeStartPosition!.dy;
    const double swipeThreshold = 25.0; // Increased threshold slightly

    if (dx.abs() > swipeThreshold || dy.abs() > swipeThreshold) {
      String swipeDir = "";
      if (dx.abs() > dy.abs()) {
        if (dx < 0) swipeDir = 'left';
        // else swipeDir = 'right'; // If you need right swipe
      } else {
        if (dy > 0) swipeDir = 'down';
        // else swipeDir = 'up'; // If you need up swipe
      }

      if (swipeDir.isNotEmpty) {
        // print("Swipe detected: $swipeDir on $_swipeCellRow, $_swipeCellCol"); // Debugging
        _handleSwipe(_swipeCellRow!, _swipeCellCol!, swipeDir);
      }
      _swipeStartPosition = null; // Reset after handling
      _swipeCellRow = null;
      _swipeCellCol = null;
    }
  }

  void _onPanEnd(DragEndDetails details) {
    _swipeStartPosition = null;
    _swipeCellRow = null;
    _swipeCellCol = null;
  }

  Color _getContrastColor(Color backgroundColor) {
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('تحميل اللغز ${widget.puzzleNumber}...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final bool isRtl = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        automaticallyImplyLeading: false,
                // Set the height
        toolbarHeight: 120,
        
        title: Text('لغز رقم ${widget.puzzleNumber}',
        textAlign: TextAlign.center,
        style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),),
        
      ),
      body: Center(
        // Center the AspectRatio
        child: AspectRatio(
          // Use AspectRatio to maintain square shape
          aspectRatio: 1.0,
          child: Container(
            margin: const EdgeInsets.all(
              8.0,
            ), // Margin for the whole grid container
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade700, width: 2),
              color: Colors.grey.shade300, // Background for spacing
            ),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: gridSize * gridSize,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: gridSize,
                mainAxisSpacing: 1.5, // Spacing between cells
                crossAxisSpacing: 1.5, // Spacing between cells
              ),
              itemBuilder: (context, index) {
                // Calculate correct cell position based on RTL setting
                final row = index ~/ gridSize;
                final col =
                    isRtl
                        ? gridSize - 1 - (index % gridSize)
                        : index % gridSize;

                // Get the correct cell data
                final cell = gridCellData[row][col]; // Adjust col based on RTL

                Color cellEffectiveColor = cell.displayColor;
                if (!cell.isBlackSquare &&
                    cell.enteredChar.isEmpty &&
                    _colorsInitialized) {
                  cellEffectiveColor = _initialCellColor;
                } else if (cell.isBlackSquare) {
                  cellEffectiveColor = Colors.black;
                }
                // If char entered, color is already set by correctness checks

                return GestureDetector(
                  key: gridKeys[row][col],
                  onPanStart: (details) => _onPanStart(details, row, col),
                  onPanUpdate: (details) => _onPanUpdate(details),
                  onPanEnd: _onPanEnd,
                  child: Container(
                    decoration: BoxDecoration(
                      color: cellEffectiveColor,
                      // borderRadius: BorderRadius.circular(1), // Optional rounded corners
                    ),
                    alignment: Alignment.center,
                    child: Stack(
                      children: [
                        if (!cell.isBlackSquare)
                          Center(
                            child: Text(
                              cell.enteredChar,
                              textDirection:
                                  TextDirection
                                      .rtl, // Ensure char itself is RTL
                              style: TextStyle(
                                color: _getContrastColor(cellEffectiveColor),
                                fontSize: gridSize > 15 ? 12 : 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
