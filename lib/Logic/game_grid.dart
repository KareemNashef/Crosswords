// Flutter imports
import 'package:flutter/material.dart';
import 'dart:math' show Point;
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

// Local imports
import 'package:crosswords/Logic/cell_model.dart';
import 'package:crosswords/Logic/clue_model.dart';
import 'package:crosswords/Logic/animated_popup.dart';

// ========== Game Grid ========== //

class GameGrid extends StatefulWidget {
  // ===== Class variables ===== //

  final String puzzleNumber;

  // Constructor
  const GameGrid({super.key, required this.puzzleNumber});

  @override
  GameGridState createState() => GameGridState();
}

class GameGridState extends State<GameGrid> with TickerProviderStateMixin {
  // ===== Class variables ===== //

  // State variables
  int gridSize = 15;
  bool isAnimating = false;
  bool _isLoading = true;
  bool _colorsInitialized = false;

  // Game variables
  Clue? activeClue;
  int? activeBlockIndexInClue;
  String? activeDirection;

  // Grid variables
  List<CellModel> cellsToAnimate = [];
  List<List<CellModel>> gridCellData = [];
  List<Clue> allParsedClues = [];
  List<List<GlobalKey>> gridKeys = [];

  // Colors
  late Color _initialCellColor;
  late Color _correctCellColor;
  late Color _errorCellColor;

  // Swipe detection
  Offset? _swipeStartPosition;
  int? _swipeCellRow;
  int? _swipeCellCol;

  // Controllers
  late AnimationController animationController;

  // ===== Class methods ===== //

  // Initialize state
  @override
  void initState() {
    super.initState();
    animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadPuzzleData();
  }

  // Initialize colors
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

  // Reapply initial colors
  void _reapplyInitialColors() {
    if (!_colorsInitialized || gridCellData.isEmpty) return;
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        final cell = gridCellData[r][c];
        if (cell.isBlackSquare) {
          cell.displayColor = Colors.black;
        } else if (cell.enteredChar.isEmpty) {
          cell.displayColor = _initialCellColor;
        }
      }
    }
  }

  // Load puzzle data
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

await _loadSavedProgress();

if (mounted) {
  setState(() {
    _isLoading = false;
    if (_colorsInitialized) _reapplyInitialColors();
  });
}
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Initialize gridCellData
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

  // Initialize gridKeys
  void _initializeKeys() {
    gridKeys = List.generate(
      gridSize,
      (r) => List.generate(gridSize, (c) => GlobalKey()),
    );
  }

  // Assign clues to cells
  void _assignCluesToCells() {
    // Renamed
    // Clear any previous assignments
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        gridCellData[r][c].acrossClue = null;
        gridCellData[r][c].acrossBlockIndex = null;
        gridCellData[r][c].downClue = null;
        gridCellData[r][c].downBlockIndex = null;
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

  // Get cell rect
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

  // Save progress
  void _savePuzzleProgress() async {
    final prefs = await SharedPreferences.getInstance();

    // Create a map to store entered characters
    Map<String, dynamic> progressData = {};



    // Store all entered characters
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        final cell = gridCellData[r][c];
        if (!cell.isBlackSquare && cell.enteredChar.isNotEmpty) {
          // Use a key format that combines row and column
          progressData['${r}_$c'] = cell.enteredChar;
        }
      }
    }

    // Progress percentage
    int progress = 0;
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        final cell = gridCellData[r][c];
        if (!cell.isBlackSquare && cell.enteredChar.isNotEmpty) {
          progress += 1;
        }
      }
    }
    progressData['progress'] = progress == gridSize * gridSize ? "Done" : "In Progress";

    // Save as JSON
    await prefs.setString(
      'puzzle_progress_${widget.puzzleNumber}',
      jsonEncode(progressData),
    );

    
  }

  // Load progress
  Future<void> _loadSavedProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final savedProgressJson = prefs.getString(
      'puzzle_progress_${widget.puzzleNumber}',
    );

    if (savedProgressJson != null) {
      try {
        final Map<String, dynamic> progressData = jsonDecode(savedProgressJson);

        // Apply saved characters to the grid
        progressData.forEach((key, value) {
          final coords = key.split('_');
          if (coords.length == 2) {
            final r = int.tryParse(coords[0]);
            final c = int.tryParse(coords[1]);

            if (r != null &&
                c != null &&
                r >= 0 &&
                r < gridSize &&
                c >= 0 &&
                c < gridSize) {
              final cell = gridCellData[r][c];
              if (!cell.isBlackSquare) {
                cell.enteredChar = value;
                // Update cell color based on correctness
                if (cell.isCurrentCharCorrect) {
                  cell.displayColor = _correctCellColor;
                } else if (cell.enteredChar.isNotEmpty) {
                  cell.displayColor = _errorCellColor;
                }
              }
            }
          }
        });
      } catch (e) {
        // Handle error
      }
    }
  }

  // Show animated popup
  void _showAnimatedPopup() {
    if (!_colorsInitialized ||
        activeClue == null ||
        activeBlockIndexInClue == null) {
      return;
    }

    setState(() => isAnimating = true);
    animationController.reset();
    animationController.forward();

    final String currentClueText =
        activeClue!.clueTexts[activeBlockIndexInClue!];
    final String currentWordSolution =
        activeClue!.blockSolutions[activeBlockIndexInClue!];

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder: (BuildContext context) {
        return AnimatedPopup(
          cellsToAnimate: cellsToAnimate,
          animationController: animationController,
          direction: activeDirection!,
          clueText: currentClueText,
          wordSolution: currentWordSolution,
          initialCellColor: _initialCellColor,
          correctCellColor: _correctCellColor,
          errorCellColor: _errorCellColor,
onSubmitOrDismiss: (Map<int, String> enteredCharsMap) {
  Navigator.of(context).pop();
  for (final cell in cellsToAnimate) {
    String? enteredForThisCell = enteredCharsMap[cell.animationIndex];
    if (enteredForThisCell != null) {
      cell.enteredChar = enteredForThisCell;
      if (cell.isCurrentCharCorrect) {
        cell.displayColor = _correctCellColor;
      } else if (cell.enteredChar.isNotEmpty) {
        cell.displayColor = _errorCellColor;
      } else {
        cell.displayColor = _initialCellColor;
      }
    }
  }
  
  _savePuzzleProgress();
},
        );
      },
    ).then((_) {
      animationController.reverse().whenComplete(() {
        // Use whenComplete for safety
        if (mounted) {
          setState(() {
            isAnimating = false;
          });
        }
      });
    });
  }

  // Handle swipe
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
      cellsToAnimate.clear();
      Point<int> startCoord =
          activeClue!.blockStartCoords[activeBlockIndexInClue!];
      int length = activeClue!.blockLengths[activeBlockIndexInClue!];

      if (activeDirection == "horizontal") {
        List<CellModel> physicalOrderCells = [];
        for (int i = 0; i < length; i++) {
          CellModel cell =
              gridCellData[startCoord.x.toInt()][startCoord.y.toInt() + i];
          physicalOrderCells.add(cell);
        }

        final bool isAppRTL =
            Localizations.localeOf(context).languageCode == 'ar';
        if (isAppRTL) {
          physicalOrderCells = physicalOrderCells.reversed.toList();
        }

        for (int i = 0; i < physicalOrderCells.length; i++) {
          CellModel cell = physicalOrderCells[i];
          final rect = _getCellRect(cell.row, cell.col);
          if (rect != null) {
            cell.originalRect = rect;
            cell.animationIndex = i;
            cellsToAnimate.add(cell);
          }
        }
      } else {
        for (int i = 0; i < length; i++) {
          CellModel cellInWord =
              gridCellData[startCoord.x.toInt() + i][startCoord.y.toInt()];
          final rect = _getCellRect(cellInWord.row, cellInWord.col);
          if (rect != null) {
            cellInWord.originalRect = rect;
            cellInWord.animationIndex = i;
            cellsToAnimate.add(cellInWord);
          }
        }
      }

      if (cellsToAnimate.isNotEmpty) {
        _showAnimatedPopup();
      }
    }
  }

  void _onPanStart(DragStartDetails details, int row, int col) {
    if (isAnimating || gridCellData[row][col].isBlackSquare) return;
    _swipeStartPosition = details.globalPosition;
    _swipeCellRow = row;
    _swipeCellCol = col;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (isAnimating ||
        _swipeStartPosition == null ||
        _swipeCellRow == null ||
        _swipeCellCol == null) {
      return;
    }
    if (gridCellData[_swipeCellRow!][_swipeCellCol!].isBlackSquare) {
      _swipeStartPosition = null;
      return;
    }

    final dx = details.globalPosition.dx - _swipeStartPosition!.dx;
    final dy = details.globalPosition.dy - _swipeStartPosition!.dy;
    const double swipeThreshold = 25.0;

    if (dx.abs() > swipeThreshold || dy.abs() > swipeThreshold) {
      String swipeDir = "";
      if (dx.abs() > dy.abs()) {
        if (dx < 0) swipeDir = 'left';
      } else {
        if (dy > 0) swipeDir = 'down';
      }

      if (swipeDir.isNotEmpty) {
        _handleSwipe(_swipeCellRow!, _swipeCellCol!, swipeDir);
      }
      _swipeStartPosition = null;
      _swipeCellRow = null;
      _swipeCellCol = null;
    }
  }

  void _onPanEnd(DragEndDetails details) {
    _swipeStartPosition = null;
    _swipeCellRow = null;
    _swipeCellCol = null;
  }

  // Method to get the contrast color
  Color _getContrastColor(Color backgroundColor) {
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  // Dispose the animation controller
  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  // ===== Build method ===== //

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
        toolbarHeight: 120,

        title: Text(
          'لغز رقم ${widget.puzzleNumber}',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Center(
        child: AspectRatio(
          aspectRatio: 1.0,
          child: Container(
            margin: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade700, width: 2),
              color: Colors.grey.shade300,
            ),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: gridSize * gridSize,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: gridSize,
                mainAxisSpacing: 1.5,
                crossAxisSpacing: 1.5,
              ),
              itemBuilder: (context, index) {
                final row = index ~/ gridSize;
                final col =
                    isRtl
                        ? gridSize - 1 - (index % gridSize)
                        : index % gridSize;

                final cell = gridCellData[row][col];

                Color cellEffectiveColor = cell.displayColor;
                if (!cell.isBlackSquare &&
                    cell.enteredChar.isEmpty &&
                    _colorsInitialized) {
                  cellEffectiveColor = _initialCellColor;
                } else if (cell.isBlackSquare) {
                  cellEffectiveColor = Colors.black;
                }

                return GestureDetector(
                  key: gridKeys[row][col],
                  onPanStart: (details) => _onPanStart(details, row, col),
                  onPanUpdate: (details) => _onPanUpdate(details),
                  onPanEnd: _onPanEnd,
                  child: Container(
                    decoration: BoxDecoration(color: cellEffectiveColor),
                    alignment: Alignment.center,
                    child: Stack(
                      children: [
                        if (!cell.isBlackSquare)
                          Center(
                            child: Text(
                              cell.enteredChar,
                              textDirection: TextDirection.rtl,
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
