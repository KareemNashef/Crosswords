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
  bool isPuzzleSolved = false;

  // Grid variables
  List<CellModel> cellsToAnimate = [];
  List<List<CellModel>> gridCellData = [];
  List<Clue> allParsedClues = [];
  List<List<GlobalKey>> gridKeys = [];

  // Colors
  late Color _initialCellColor;
  late Color _correctCellColor;
  late Color _errorCellColor;
  late Color _selectionCellColor;
  Map<CellModel, Color> originalColors = {};

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
      duration: const Duration(milliseconds: 100),
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
      _selectionCellColor = Colors.amber; // More visible yellow
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
        if (cell.isBlackSquare || cell.isCurrentCharCorrect) {
          progress += 1;
        }
      }
    }

    // Update progress
    progressData['progress'] =
        progress == gridSize * gridSize ? "Done" : "In Progress";

    // Check if done
    if (progress == gridSize * gridSize) {
      showLevelCompleteDialog(context);

      setState(() {
        isPuzzleSolved = true;
      });
    }

    // Save as JSON
    await prefs.setString(
      'puzzle_progress_${widget.puzzleNumber}',
      jsonEncode(progressData),
    );
  }

  void showLevelCompleteDialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true, // Allow closing by tapping outside
      barrierColor: Colors.black54,
      barrierLabel: "Dismiss Dialog", // Set barrierLabel
      transitionDuration: Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => Center(),
      transitionBuilder: (_, anim, __, ___) {
        return Transform.scale(
          scale: anim.value,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: Color(0xFF2A2A2A),
            contentPadding: EdgeInsets.all(24),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star, size: 100, color: Colors.amber),
                SizedBox(height: 20),
                Text(
                  "لقد أكملت المستوى بنجاح!",
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontFamily: 'Cairo',
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
                Text(
                  "مبروك! استمتع بمستوى جديد!",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    fontFamily: 'Cairo',
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
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

        if (progressData['progress'] == "Done") {
          isPuzzleSolved = true;
        }

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
      // Restore original colors before showing popup
      if (originalColors.isNotEmpty) {
        for (final cell in cellsToAnimate) {
          if (originalColors.containsKey(cell)) {
            if (cell.displayColor == _selectionCellColor) {
              cell.displayColor = originalColors[cell]!;
            }
          }
        }
        // Update the UI with restored colors
        setState(() {});
      }

      // Clear the map after popup is closed
      originalColors.clear();

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
      originalColors.clear(); // Clear previous original colors

      Point<int> startCoord =
          activeClue!.blockStartCoords[activeBlockIndexInClue!];
      int length = activeClue!.blockLengths[activeBlockIndexInClue!];

      if (activeDirection == "horizontal") {
        List<CellModel> physicalOrderCells = [];
        for (int i = 0; i < length; i++) {
          CellModel cell =
              gridCellData[startCoord.x.toInt()][startCoord.y.toInt() + i];
          physicalOrderCells.add(cell);

          // Store original color and change to selection color
          originalColors[cell] = cell.displayColor;
          cell.displayColor = _selectionCellColor;
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

          // Store original color and change to selection color
          originalColors[cellInWord] = cellInWord.displayColor;
          cellInWord.displayColor = _selectionCellColor;

          final rect = _getCellRect(cellInWord.row, cellInWord.col);
          if (rect != null) {
            cellInWord.originalRect = rect;
            cellInWord.animationIndex = i;
            cellsToAnimate.add(cellInWord);
          }
        }
      }

      // Force a rebuild to show yellow cells
      setState(() {});

      if (cellsToAnimate.isNotEmpty) {
        // Show animated popup after a brief delay to let user see yellow highlighting
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _showAnimatedPopup();
          }
        });
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

  // Reset the game state
  Future<void> _resetPuzzle() async {
    // Clear saved progress
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('puzzle_progress_${widget.puzzleNumber}');

    // Reset game variables
    setState(() {
      isPuzzleSolved = false;
      activeClue = null;
      activeBlockIndexInClue = null;
      activeDirection = null;
      cellsToAnimate.clear();
      originalColors.clear();
    });

    // Reload the puzzle data to get a fresh grid
    await _loadPuzzleData();

    // Reapply initial colors to the grid
    _reapplyInitialColors();

    // Force a rebuild of the UI
    if (mounted) {
      setState(() {});
    }
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

    // --- Configuration for Headers and Grid ---
    final double rowHeaderWidth = 30.0; // Width of the column for row numbers
    final double gridMarginAllSides = 8.0; // Margin of the grid container
    final double gridBorderWidthAllSides =
        2.0; // Border width of the grid container
    final double headerSpacing =
        4.0; // Space between column headers and the grid/row-headers block

    // --- Helper Widget for Column Numbers ---
    Widget _buildColumnHeaders() {
      return Padding(
        // This inner padding aligns numbers with grid cells, accounting for the grid's border.
        // The outer alignment (with grid's margin) is handled by the parent Container of this widget.
        padding: EdgeInsets.symmetric(horizontal: gridBorderWidthAllSides),
        child: Row(
          children: List.generate(gridSize, (index) {
            final columnNumber = index + 1; // Numbers are always 1, 2, 3...
            return Expanded(
              child: Center(
                child: Text(
                  '$columnNumber',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color:
                        Theme.of(
                          context,
                        ).colorScheme.primary, // Or Theme.of(context)...
                  ),
                ),
              ),
            );
          }),
        ),
      );
    }

    // --- Helper Widget for Row Numbers ---
    Widget _buildRowHeaders() {
      return Container(
        width: rowHeaderWidth,
        // Vertical padding to align numbers top/bottom with grid cells,
        // accounting for the grid container's outer margin and border.
        padding: EdgeInsets.symmetric(
          vertical: gridMarginAllSides + gridBorderWidthAllSides,
        ),
        child: Column(
          // mainAxisAlignment: MainAxisAlignment.spaceAround, // Distributes space
          children: List.generate(gridSize, (index) {
            final rowNumber = index + 1;
            return Expanded(
              // Each number takes equal vertical space
              child: Center(
                child: Text(
                  '$rowNumber',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color:
                        Theme.of(
                          context,
                        ).colorScheme.primary, // Or Theme.of(context)...
                  ),
                ),
              ),
            );
          }),
        ),
      );
    }

    // --- The main Grid Widget itself ---
    Widget actualGridWidget = Center(
      child: AspectRatio(
        aspectRatio: 1.0,
        child: Container(
          margin: EdgeInsets.all(gridMarginAllSides),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outline,
              width: gridBorderWidthAllSides,
            ),
            color: Theme.of(context).colorScheme.outline,
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
              // This 'col' is for data access and respects RTL for data mapping
              final col =
                  isRtl ? gridSize - 1 - (index % gridSize) : index % gridSize;

              final cell = gridCellData[row][col];

              return GestureDetector(
                key: gridKeys[row][col],
                onPanStart: (details) => _onPanStart(details, row, col),
                onPanUpdate: (details) => _onPanUpdate(details),
                onPanEnd: _onPanEnd,
                child: Container(
                  decoration: BoxDecoration(color: cell.displayColor),
                  alignment: Alignment.center,
                  child: Stack(
                    children: [
                      if (!cell.isBlackSquare)
                        Center(
                          child: Text(
                            cell.enteredChar,
                            textDirection:
                                TextDirection.rtl, // Character itself is RTL
                            style: TextStyle(
                              color: _getContrastColor(cell.displayColor),
                              fontSize: 14,
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
    );

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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              SizedBox(height: 40),
              Row(
                children: <Widget>[
                  if (isRtl) SizedBox(width: rowHeaderWidth),
                  Expanded(
                    child: Container(
                      margin: EdgeInsets.symmetric(
                        horizontal: gridMarginAllSides,
                      ),
                      child: _buildColumnHeaders(),
                    ),
                  ),
                  if (!isRtl) SizedBox(width: rowHeaderWidth),
                ],
              ),

              SizedBox(height: headerSpacing),

              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _buildRowHeaders(),
                    Expanded(child: actualGridWidget),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              if (isPuzzleSolved)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "الرجوع إلى الصفحة الرئيسية",
                    style: TextStyle(fontSize: 16, color: Colors.black),
                  ),
                ),

              const SizedBox(height: 20),
              if (isPuzzleSolved)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                  ),
                  onPressed: () => _resetPuzzle(),
                  child: Text(
                    "اللعب من جديد",
                    style: TextStyle(fontSize: 16, color: Colors.black),
                  ),
                ),

            ],
          ),
        ),
      ),
    );
  }
}
