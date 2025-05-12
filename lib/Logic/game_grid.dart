// Flutter imports
import 'dart:async';
import 'dart:convert';
import 'dart:math' show Point;
import 'package:crosswords/Logic/active_group_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

// Local imports
import 'package:crosswords/Settings/firebase.dart';
import 'package:crosswords/Logic/puzzle_firebase_service.dart';
import 'package:crosswords/Settings/group.dart';
import 'package:crosswords/Logic/cell_model.dart';
import 'package:crosswords/Logic/clue_model.dart';
import 'package:crosswords/Logic/animated_popup.dart';

class GameGrid extends StatefulWidget {
  final String puzzleNumber;
  const GameGrid({super.key, required this.puzzleNumber});

  @override
  GameGridState createState() => GameGridState();
}

class GameGridState extends State<GameGrid> with TickerProviderStateMixin {
  // Grid & Game State
  int gridSize = 15;
  List<List<CellModel>> gridCellData = [];
  List<Clue> allParsedClues = [];
  List<List<GlobalKey>> gridKeys = [];
  bool _isLoading = true;
  bool isPuzzleSolved = false;

  // Active Selection State
  Clue? activeClue;
  int? activeBlockIndexInClue;
  String? activeDirection;
  List<CellModel> cellsToAnimate = [];
  Map<CellModel, Color> originalHighlightColors = {};

  // Animation & UI State
  late AnimationController _animationController;
  bool isAnimating = false;
  bool _colorsInitialized = false;

  // Theme Colors
  late Color _initialCellColor;
  late Color _correctCellColor;
  late Color _errorCellColor;
  late Color _selectionCellColor;

  // Swipe Detection
  Offset? _swipeStartPosition;
  int? _swipeCellRow;
  int? _swipeCellCol;

  // Firebase & Group State
  late PuzzleFirebaseService _puzzleFirebaseService;
  late GroupFirebaseService _groupFirebaseService;
  String _currentGroupName = '';
  String _currentUserName = '';
  bool _isInGroup = false;
  StreamSubscription? _puzzleSubscription;
  Map<String, String> _userColors = {};

  @override
  void initState() {
    super.initState();
    _puzzleFirebaseService = PuzzleFirebaseService();
    _groupFirebaseService = GroupFirebaseService();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );

    // Initialize: Load user info -> Load puzzle structure & progress -> Subscribe
    _initializeGame();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize theme-dependent colors once the context is available
    if (!_colorsInitialized) {
      _initializeColors();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _puzzleSubscription?.cancel(); // Crucial for preventing memory leaks
    super.dispose();
  }

  // --- Initialization Flow ---

  Future<void> _initializeGame() async {
    await _loadUserAndGroupInfo();
    await _loadPuzzleDataAndProgress();
    if (_isInGroup) {
      _subscribeToPuzzleUpdates();
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUserAndGroupInfo() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserName = prefs.getString('userName') ?? '';
    _currentGroupName = prefs.getString('groupName') ?? '';
    _isInGroup = prefs.getBool('inGroup') ?? false;

    if (_isInGroup && _currentGroupName.isNotEmpty) {
      await _loadGroupUsersColors();
    }
  }

  Future<void> _loadGroupUsersColors() async {
    if (!_isInGroup || _currentGroupName.isEmpty) return;

    // Get all users in the group
    final users = await _groupFirebaseService.getGroupUsers(_currentGroupName);

    if (mounted) {
      // Ensure values are strings (Firestore might return dynamic)
      _userColors = Map<String, String>.fromEntries(
        users.entries.map((e) => MapEntry(e.key, e.value.toString())),
      );
    }
  }

  Future<void> _initializeColors() async {
    if (_colorsInitialized) return; // Already initialized
    final prefs = await SharedPreferences.getInstance();
    final theme = Theme.of(context);

    // Initialize theme-dependent colors
    _initialCellColor = theme.colorScheme.secondaryContainer;
    _errorCellColor = theme.colorScheme.errorContainer;
    _selectionCellColor = Colors.amber;

    // Initialize correct cell color
    final savedColorHex = prefs.getString('selectedColor');

    // If saved color is valid, use it
    if (savedColorHex != null && savedColorHex.startsWith('#')) {
      _correctCellColor = hexStringToColor(savedColorHex);
    } else {
      _correctCellColor = theme.colorScheme.primaryContainer;
    }

    // Mark colors as initialized
    _colorsInitialized = true;

    // If grid data loaded before colors were ready, apply colors now
    if (gridCellData.isNotEmpty) {
      _reapplyAllCellColors();
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadPuzzleDataAndProgress() async {
    // Ensure colors are ready before proceeding, especially for initial display
    if (!_colorsInitialized) {
      await _initializeColors();
    }

    if (!mounted) return; // Check if widget is still mounted
    setState(() => _isLoading = true);

    try {
      // Load puzzle structure & progress
      await _loadPuzzleStructure();
      await _loadInitialProgress();

      // Final check and update after loading everything
      if (mounted) {
        _reapplyAllCellColors();
        isPuzzleSolved = _checkIfPuzzleCompleteLocally();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadPuzzleStructure() async {
    // Load, parse, and initialize puzzle structure
    final solutionJsonString = await rootBundle.loadString(
      'assets/Puzzles/puzzle_${widget.puzzleNumber}_solution.json',
    );
    final List<dynamic> decodedSolutionsRaw = json.decode(solutionJsonString);
    final List<List<String>> solutionGrid =
        decodedSolutionsRaw.map((row) => List<String>.from(row)).toList();

    // Check if solution grid is empty
    if (solutionGrid.isEmpty) throw Exception("Solution grid is empty");
    gridSize = solutionGrid.length;

    // Initialize grid cells and keys
    _initializeGridCells(solutionGrid);
    _initializeKeys();

    // Load, parse, and initialize puzzle clues
    final cluesJsonRawString = await rootBundle.loadString(
      'assets/Puzzles/puzzle_${widget.puzzleNumber}_clues.json',
    );
    final List<dynamic> decodedCluesJson = json.decode(cluesJsonRawString);

    allParsedClues.clear();
    for (var clueJsonEntry in decodedCluesJson) {
      if (clueJsonEntry is Map<String, dynamic>) {
        Clue parsedClue = Clue.fromJson(clueJsonEntry, gridSize, solutionGrid);
        if (parsedClue.blockSolutions.isNotEmpty) {
          allParsedClues.add(parsedClue);
        }
      }
    }

    // Assign clues to cells
    _assignCluesToCells();
  }

  void _initializeGridCells(List<List<String>> solutionGrid) {
    // Use a temporary color if theme colors aren't ready yet, will be fixed by _reapplyAllCellColors
    Color tempInitialColor =
        _colorsInitialized ? _initialCellColor : Colors.grey.shade300;

    // Initialize grid cells
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
          madeBy: '', // Initial state
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
    // Clear previous assignments
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        gridCellData[r][c].acrossClue = null;
        gridCellData[r][c].acrossBlockIndex = null;
        gridCellData[r][c].downClue = null;
        gridCellData[r][c].downBlockIndex = null;
      }
    }

    // Assign based on parsed clues
    for (final clue in allParsedClues) {
      for (
        int blockIdx = 0;
        blockIdx < clue.blockSolutions.length;
        blockIdx++
      ) {
        Point<int> startCoord = clue.blockStartCoords[blockIdx];
        int length = clue.blockLengths[blockIdx];
        for (int i = 0; i < length; i++) {
          int r = startCoord.x;
          int c = startCoord.y;
          CellModel currentCell;
          if (clue.direction == "horizontal") {
            currentCell = gridCellData[r][c + i];
            currentCell.acrossClue = clue;
            currentCell.acrossBlockIndex = blockIdx;
          } else {
            // vertical
            currentCell = gridCellData[r + i][c];
            currentCell.downClue = clue;
            currentCell.downBlockIndex = blockIdx;
          }
        }
      }
    }
  }

  Future<void> _loadInitialProgress() async {
    Map<String, dynamic>? progressData;
    bool loadedFromFirebase = false;

    // Load progress from Firebase
    if (_isInGroup && _currentGroupName.isNotEmpty) {
      progressData =
          await _puzzleFirebaseService
              .streamPuzzleProgress(_currentGroupName, widget.puzzleNumber)
              .first;
      if (progressData.isNotEmpty) {
        loadedFromFirebase = true;
      }
    }

    // Fallback to local storage if not in group or Firebase fetch failed/empty
    if (!loadedFromFirebase) {
      final prefs = await SharedPreferences.getInstance();
      final savedProgressJson = prefs.getString(
        'puzzle_progress_${widget.puzzleNumber}',
      );
      if (savedProgressJson != null) {
        try {
          progressData = jsonDecode(savedProgressJson);

          // If we loaded local data AND are in a group, sync it TO Firebase
          if (_isInGroup &&
              _currentGroupName.isNotEmpty &&
              progressData != null &&
              progressData.isNotEmpty) {
            await _syncLocalMapToFirebase(progressData);
          }
        } catch (e) {
          progressData = null;
        }
      }
    }

    // Apply the loaded progress (if any)
    if (progressData != null && progressData.isNotEmpty) {
      _applyRemotePuzzleProgress(progressData, isInitialLoad: true);
    } else {
      print("Starting puzzle fresh - no saved progress found.");
    }
  }

  // --- Firebase & Syncing ---

  void _subscribeToPuzzleUpdates() {
    // If not in group or puzzle number is empty, don't subscribe
    if (!_isInGroup ||
        _currentGroupName.isEmpty ||
        widget.puzzleNumber.isEmpty) {
      return;
    }

    // Cancel previous subscription if any
    _puzzleSubscription?.cancel();

    // Subscribe
    _puzzleSubscription = _puzzleFirebaseService
        .streamPuzzleProgress(_currentGroupName, widget.puzzleNumber)
        .listen((progressData) {
          if (mounted && gridCellData.isNotEmpty && _colorsInitialized) {
            _applyRemotePuzzleProgress(progressData);
          }
        });
  }

  void _applyRemotePuzzleProgress(
    Map<String, dynamic> progressData, {
    bool isInitialLoad = false,
  }) {
    // Check if we need to update the UI
    bool needsUIUpdate = false;
    bool puzzleCompletionStatusChanged = false;
    bool remoteReportsDone = progressData['progress'] == 'Done';

    // Iterate over progress data
    progressData.forEach((key, value) {
      // Skip metadata keys
      if (key == 'progress') return;

      // Process cell data (key format 'r_c')
      final parts = key.split('_');
      if (parts.length != 2) return;
      final r = int.tryParse(parts[0]);
      final c = int.tryParse(parts[1]);

      if (r != null &&
          c != null &&
          r >= 0 &&
          r < gridSize &&
          c >= 0 &&
          c < gridSize) {
        final cell = gridCellData[r][c];
        if (cell.isBlackSquare) return;

        // Get remote data
        String remoteChar = value['char'] ?? '';
        String remoteMadeBy = value['madeBy'] ?? '';

        // Update cell only if necessary
        if (cell.enteredChar != remoteChar || cell.madeBy != remoteMadeBy) {
          cell.enteredChar = remoteChar;
          cell.madeBy = remoteMadeBy;
          _updateCellColor(cell);
          needsUIUpdate = true;
        }
      }
    });

    // Check local completion status after applying all changes
    bool isNowLocallyComplete = _checkIfPuzzleCompleteLocally();

    // Update overall puzzle solved state
    if (isPuzzleSolved != isNowLocallyComplete) {
      // If the puzzle is now complete locally, but Firebase doesn't say 'Done' yet,
      // OR if Firebase says 'Done', ensure our local state matches.
      if (isNowLocallyComplete || remoteReportsDone) {
        if (!isPuzzleSolved) {
          // Only update if changing state
          isPuzzleSolved = true;
          puzzleCompletionStatusChanged = true;
          needsUIUpdate = true;
          // If *we* just completed it locally, tell Firebase.
          if (isNowLocallyComplete && !remoteReportsDone && _isInGroup) {
            _updateFirebaseProgressMetadata("Done");
          }
        }
      } else {
        // Puzzle is not locally complete and Firebase doesn't say 'Done'
        if (isPuzzleSolved) {
          // Only update if changing state
          isPuzzleSolved = false;
          puzzleCompletionStatusChanged = true;
          needsUIUpdate = true;
          // If Firebase reported 'Done' but local isn't, correct Firebase? Or just local?
          // Let's assume local check overrides for now unless Firebase is the source of truth
          if (remoteReportsDone && _isInGroup) {
            _updateFirebaseProgressMetadata(
              "In Progress",
            ); // Correct Firebase if needed
          }
        }
      }
    }

    if (needsUIUpdate && mounted) {
      setState(() {});
    }

    // Show completion dialog only once when state changes to solved
    if (puzzleCompletionStatusChanged && isPuzzleSolved && !isInitialLoad) {
      _showLevelCompleteDialog();
    }
  }

  Future<void> _syncCellChangeToFirebase(
    int r,
    int c,
    String char,
    String madeBy,
  ) async {
    // If not in group or puzzle number is empty, don't sync
    if (!_isInGroup || _currentGroupName.isEmpty || _currentUserName.isEmpty) {
      return;
    }

    // Sync
    await _puzzleFirebaseService.updatePuzzleCell(
      _currentGroupName,
      widget.puzzleNumber,
      r,
      c,
      char,
      madeBy,
    );
  }

  Future<void> _syncLocalMapToFirebase(Map<String, dynamic> progressMap) async {
    // If not in group or puzzle number is empty, don't sync
    if (!_isInGroup || _currentGroupName.isEmpty) return;

    // Sync
    await _puzzleFirebaseService.updatePuzzleProgressBatch(
      _currentGroupName,
      widget.puzzleNumber,
      progressMap,
    );
  }

  Future<void> _updateFirebaseProgressMetadata(String status) async {
    // If not in group or puzzle number is empty, don't sync
    if (!_isInGroup || _currentGroupName.isEmpty) return;

    // Sync
    await _puzzleFirebaseService.updatePuzzleMetadata(
      _currentGroupName,
      widget.puzzleNumber,
      {'progress': status},
    );
  }

  // --- Local Persistence & State ---

  Future<void> _savePuzzleProgressLocally() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> progressData = {};

    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        final cell = gridCellData[r][c];
        if (!cell.isBlackSquare && cell.enteredChar.isNotEmpty) {
          progressData['${r}_$c'] = {
            'char': cell.enteredChar,
            'madeBy': cell.madeBy,
          };
        }
      }
    }

    // Re-check completion status before saving metadata
    isPuzzleSolved = _checkIfPuzzleCompleteLocally();
    final String currentStatus = isPuzzleSolved ? "Done" : "In Progress";
    progressData['progress'] = currentStatus;

    await prefs.setString(
      'puzzle_progress_${widget.puzzleNumber}',
      jsonEncode(progressData),
    );

    // Also update Firebase metadata if the status changed due to local action
    if (_isInGroup) {
      // Maybe only update if status *changed*? Check against previous known FB status?
      // For simplicity, let's update it based on the current local check.
      _updateFirebaseProgressMetadata(currentStatus);
    }

    // Trigger UI update and dialog if solved locally
    if (isPuzzleSolved && mounted) {
      setState(() {}); // Ensure UI reflects solved state
      _showLevelCompleteDialog();
    }
  }

  bool _checkIfPuzzleCompleteLocally() {
    // Check if all cells are correct
    if (gridCellData.isEmpty) return false;
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        final cell = gridCellData[r][c];
        if (!cell.isBlackSquare && !cell.isCurrentCharCorrect) {
          return false;
        }
      }
    }
    return true; // All cells are correct
  }

  Future<void> _resetPuzzle() async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('إعادة ضبط اللغز؟', textDirection: TextDirection.rtl),
            content: Text(
              'هل أنت متأكد أنك تريد مسح كل التقدم لهذا اللغز؟',
              textDirection: TextDirection.rtl,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('إلغاء'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('إعادة الضبط'),
              ),
            ],
          ),
    );
    // User cancelled
    if (confirm != true) return;

    // Reset
    if (!mounted) return;
    setState(() => _isLoading = true);

    // 1. Clear local state
    isPuzzleSolved = false;
    activeClue = null;
    activeBlockIndexInClue = null;
    activeDirection = null;
    cellsToAnimate.clear();
    _clearSelectionHighlight(forceUpdate: false);

    // Reset grid data
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        if (!gridCellData[r][c].isBlackSquare) {
          gridCellData[r][c].enteredChar = '';
          gridCellData[r][c].madeBy = '';
        }
      }
    }

    // Re-apply colors
    _reapplyAllCellColors();

    // 2. Clear local saved progress
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('puzzle_progress_${widget.puzzleNumber}');

    // 3. Clear Firebase progress (if in group)
    if (_isInGroup && _currentGroupName.isNotEmpty) {
      await _puzzleFirebaseService.resetPuzzleProgress(
        _currentGroupName,
        widget.puzzleNumber,
      );
    }

    // 4. Update UI
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // --- Cell & Color Updates ---

  void _updateCellColor(CellModel cell) {
    // Only update if colors are initialized
    if (!_colorsInitialized) return;

    // If cell is black, use black
    if (cell.isBlackSquare) {
      cell.displayColor = Colors.black;
    }
    // If cell is selected, use selection
    else if (originalHighlightColors.containsKey(cell)) {
      cell.displayColor = _selectionCellColor;
    }
    // If cell is empty, use initial
    else if (cell.enteredChar.isEmpty) {
      cell.displayColor = _initialCellColor;
    }
    // Cell has an entered character
    else {
      if (cell.isCurrentCharCorrect) {
        // Correct: Use the color of the user who entered it, if available and in group
        if (_isInGroup &&
            cell.madeBy.isNotEmpty &&
            _userColors.containsKey(cell.madeBy)) {
          final hexColor = _userColors[cell.madeBy]!;
          try {
            cell.displayColor = hexStringToColor(hexColor);
          } catch (e) {
            cell.displayColor = _correctCellColor; // Fallback
          }
        } else {
          // Not in group, or unknown user: Use the current user's correct color
          cell.displayColor = _correctCellColor;
        }
      } else {
        // Incorrect: Use the error color
        cell.displayColor = _errorCellColor;
      }
    }
  }

  void _reapplyAllCellColors() {
    // Only update if colors are initialized
    if (!_colorsInitialized || gridCellData.isEmpty) return;

    // Re-apply colors
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        if (!gridCellData[r][c].isBlackSquare) {
          _updateCellColor(gridCellData[r][c]);
        }
      }
    }
  }

  // --- UI Interaction & Animations ---

  Rect? _getCellRect(int row, int col) {
    // Out of bounds
    if (row < 0 ||
        row >= gridSize ||
        col < 0 ||
        col >= gridSize ||
        gridKeys.isEmpty) {
      return null;
    }

    // Get the context for the specified cell
    final context = gridKeys[row][col].currentContext;
    if (context == null) return null;

    // Get the render box to compute position and size
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;

    // Convert the position to global coordinates
    final position = box.localToGlobal(Offset.zero);

    // Return the cell's rectangle on screen
    return Rect.fromLTWH(
      position.dx,
      position.dy,
      box.size.width,
      box.size.height,
    );
  }

  void _handleSwipe(int r, int c, String swipeGestureDirection) {
    // If already animating or cell is black, ignore
    if (isAnimating || gridCellData[r][c].isBlackSquare) return;

    // Determine active clue based on swipe
    CellModel swipedCell = gridCellData[r][c];
    Clue? targetClue;
    int? targetBlockIndex;
    String? targetDirection;

    // 'left' swipe activates horizontal in RTL
    if (swipeGestureDirection == 'left' && swipedCell.acrossClue != null) {
      targetDirection = "horizontal";
      targetClue = swipedCell.acrossClue;
      targetBlockIndex = swipedCell.acrossBlockIndex;
    }
    // 'down' swipe activates vertical
    else if (swipeGestureDirection == 'down' && swipedCell.downClue != null) {
      targetDirection = "vertical";
      targetClue = swipedCell.downClue;
      targetBlockIndex = swipedCell.downBlockIndex;
    }
    // No valid clue for this swipe direction
    else {
      return;
    }

    // If the target is the same as the already active clue, show popup immediately
    if (targetClue == activeClue &&
        targetBlockIndex == activeBlockIndexInClue &&
        targetDirection == activeDirection) {
      _showAnimatedPopup();
      return;
    }

    // Clear previous selection and prepare for new one
    _clearSelectionHighlight();
    activeClue = targetClue;
    activeBlockIndexInClue = targetBlockIndex;
    activeDirection = targetDirection;
    cellsToAnimate.clear();

    // --- Prepare cells for highlight and animation ---
    Point<int> startCoord =
        activeClue!.blockStartCoords[activeBlockIndexInClue!];
    int length = activeClue!.blockLengths[activeBlockIndexInClue!];

    // Get all cells in the word
    List<CellModel> wordCells = [];
    for (int i = 0; i < length; i++) {
      int currentR =
          (activeDirection == "vertical") ? startCoord.x + i : startCoord.x;
      int currentC =
          (activeDirection == "horizontal") ? startCoord.y + i : startCoord.y;
      if (currentR < gridSize && currentC < gridSize) {
        wordCells.add(gridCellData[currentR][currentC]);
      }
    }

    // Apply RTL ordering for animation if needed (horizontal only)
    final bool isAppRTL = Directionality.of(context) == TextDirection.rtl;
    if (activeDirection == "horizontal" && isAppRTL) {
      wordCells = wordCells.reversed.toList();
    }

    // Apply highlight and store info for animation
    int animationIndex = 0;
    for (final cell in wordCells) {
      final rect = _getCellRect(cell.row, cell.col);
      if (rect != null) {
        // Store original color BEFORE highlighting
        originalHighlightColors[cell] = cell.displayColor;
        cell.displayColor = _selectionCellColor;

        cell.originalRect = rect;
        cell.animationIndex = animationIndex++;
        cellsToAnimate.add(cell);
      }
    }

    // If any cells were prepared for animation update UI immediately to show the highlight
    if (cellsToAnimate.isNotEmpty) {
      setState(() {});

      // Show popup after a short delay to let user see the highlight
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && !isAnimating && activeClue == targetClue) {
          // Ensure state hasn't changed again
          _showAnimatedPopup();
        } else if (mounted) {
          // If state changed or animation started elsewhere, clear highlight
          _clearSelectionHighlight();
        }
      });
    } else {
      // If no cells were prepared for animation, clear highlight
      _clearSelectionHighlight();
    }
  }

  void _clearSelectionHighlight({bool forceUpdate = true}) {
    // If any cells were highlighted clear them
    if (originalHighlightColors.isNotEmpty) {
      final cellsToUpdate = originalHighlightColors.keys.toList();
      originalHighlightColors.clear();

      // Recalculate the correct color for each previously highlighted cell
      for (final cell in cellsToUpdate) {
        _updateCellColor(cell);
      }

      // Update UI if requested and still mounted
      if (forceUpdate && mounted) {
        setState(() {});
      }
    }
  }

  void _showAnimatedPopup() {
    // Check if popup can be shown
    if (!mounted ||
        !_colorsInitialized ||
        cellsToAnimate.isEmpty ||
        activeClue == null ||
        activeBlockIndexInClue == null ||
        activeDirection == null) {
      _clearSelectionHighlight();
      return;
    }

    // --- Show popup ---

    // Start animation
    setState(() => isAnimating = true);
    _animationController.forward(from: 0.0);

    // Prepare popup
    final String currentClueText =
        activeClue!.clueTexts[activeBlockIndexInClue!];
    final String currentWordSolution =
        activeClue!.blockSolutions[activeBlockIndexInClue!];

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder: (BuildContext context) {
        // Show popup
        return AnimatedPopup(
          cellsToAnimate: cellsToAnimate,
          animationController: _animationController,
          direction: activeDirection!,
          clueText: currentClueText,
          wordSolution: currentWordSolution,
          initialCellColor: _initialCellColor,
          correctCellColor: _correctCellColor,
          errorCellColor: _errorCellColor,

          // Process changes from the popup
          onSubmitOrDismiss: (Map<int, String> enteredCharsMap) {
            // Process changes
            bool changed = false;
            for (final cell in cellsToAnimate) {
              // Get entered char for this cell
              String? enteredForThisCell = enteredCharsMap[cell.animationIndex];

              if (enteredForThisCell != null) {
                // If entered char is different, update
                if (cell.enteredChar != enteredForThisCell) {
                  // Update cell
                  cell.enteredChar = enteredForThisCell;
                  cell.madeBy = _currentUserName;
                  _updateCellColor(cell);

                  // Sync change to Firebase if in a group
                  _syncCellChangeToFirebase(
                    cell.row,
                    cell.col,
                    cell.enteredChar,
                    cell.madeBy,
                  );
                  changed = true;
                }
              }
            }

            // Save progress locally after applying changes
            if (changed) {
              _savePuzzleProgressLocally(); // This also checks for completion
            }

            // Ensure the dialog is popped, even if dismissed externally
            if (Navigator.canPop(context)) {
              Navigator.of(context).pop();
            }
          },
        );
      },
    )
    // This runs after the dialog is popped (by submit, dismiss, or back button)
    .whenComplete(() {
      // Restore original cell appearance
      _clearSelectionHighlight();

      // Reverse animation
      _animationController.reverse().whenComplete(() {
        if (mounted) {
          setState(() {
            isAnimating = false;
          });
        }
      });
    });
  }

  void _showLevelCompleteDialog() {
    // Check if popup can be shown
    if (!mounted || !ModalRoute.of(context)!.isCurrent || !isPuzzleSolved) {
      return;
    }

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54.withOpacity(0.6),
      barrierLabel: "Dismiss",
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) => const Center(),
      transitionBuilder: (_, anim, __, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: Theme.of(context).colorScheme.surface,
              contentPadding: const EdgeInsets.all(24),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Level complete icon
                  Icon(Icons.star, size: 80, color: Colors.amber),

                  // Padding
                  const SizedBox(height: 20),

                  // Level complete text
                  Text(
                    "لقد أكملت المستوى بنجاح!",
                    style: TextStyle(
                      fontSize: 20,
                      color: Theme.of(context).colorScheme.onSurface,
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                  ),

                  // Padding
                  const SizedBox(height: 15),

                  // Level complete text
                  Text(
                    "مبروك! استمتع بمستوى جديد!",
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontFamily: 'Cairo',
                    ),
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- Swipe Gesture Handlers ---
  void _onPanStart(DragStartDetails details, int row, int col) {
    if (isAnimating || gridCellData[row][col].isBlackSquare) return;
    _swipeStartPosition = details.globalPosition;
    _swipeCellRow = row;
    _swipeCellCol = col;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_swipeStartPosition == null ||
        _swipeCellRow == null ||
        _swipeCellCol == null ||
        isAnimating) {
      return;
    }

    if (gridCellData[_swipeCellRow!][_swipeCellCol!].isBlackSquare) {
      _resetSwipeTracking();
      return;
    }

    final dx = details.globalPosition.dx - _swipeStartPosition!.dx;
    final dy = details.globalPosition.dy - _swipeStartPosition!.dy;
    const double swipeThreshold =
        25.0; // Minimum distance to trigger swipe logic

    // Check if threshold is met in either direction
    if (dx.abs() > swipeThreshold || dy.abs() > swipeThreshold) {
      String swipeDir = "";
      // Determine dominant direction
      if (dx.abs() > dy.abs()) {
        // Horizontal
        swipeDir =
            (dx < 0)
                ? 'left'
                : 'right'; // RTL: 'left' swipe means moving finger left (word goes right-to-left)
      } else {
        // Vertical
        swipeDir = (dy > 0) ? 'down' : 'up';
      }

      // Only handle the directions relevant for clue activation
      if (swipeDir == 'left' || swipeDir == 'down') {
        _handleSwipe(_swipeCellRow!, _swipeCellCol!, swipeDir);
      }

      // Reset tracking once a swipe is processed or threshold met, regardless of handling
      _resetSwipeTracking();
    }
  }

  void _onPanEnd(DragEndDetails details) {
    // Reset if the drag ends without triggering a swipe in onPanUpdate
    _resetSwipeTracking();
  }

  void _resetSwipeTracking() {
    _swipeStartPosition = null;
    _swipeCellRow = null;
    _swipeCellCol = null;
  }

  // --- Build Method & Helpers ---

  @override
  Widget build(BuildContext context) {
    // Use a Scaffold wrapper for easy AppBar and background
    return Scaffold(appBar: _buildAppBar(), body: _buildBody());
  }

  AppBar _buildAppBar() {
    return AppBar(
      centerTitle: true,
      automaticallyImplyLeading: true,
      toolbarHeight: 100,

      // Title
      title: Text(
        'لغز رقم ${widget.puzzleNumber}',
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),

      // Actions
      actions: [
        IconButton(
          icon: Icon(
            Icons.refresh,
            color: Theme.of(context).colorScheme.primary,
          ),
          tooltip: 'إعادة ضبط اللغز',
          onPressed: _isLoading ? null : _resetPuzzle,
        ),

        // Padding
        SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBody() {
    // Loading screen
    if (_isLoading || !_colorsInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    // Constants for layout
    const double rowHeaderWidth = 30.0;
    const double gridMargin = 8.0;
    const double headerSpacing = 4.0;
    const double cellSpacing = 1.5;

    // Main layout structure
    return SingleChildScrollView(
      // Allows scrolling if content overflows vertically
      child: Padding(
        padding: const EdgeInsets.all(gridMargin),
        child: Column(
          children: [
            // Padding
            const SizedBox(height: 20),

            // --- Column Headers Row ---
            Row(
              children: <Widget>[
                SizedBox(width: gridMargin * 2.5),
                Expanded(child: _buildColumnHeaders(gridMargin)),
              ],
            ),

            // Padding
            SizedBox(height: headerSpacing),

            // --- Grid and Row Headers Row ---
            IntrinsicHeight(
              // Ensure Row Headers match Grid height
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Row Headers
                  _buildRowHeaders(rowHeaderWidth, gridMargin),

                  // Grid
                  Expanded(child: _buildActualGrid(gridMargin, cellSpacing)),
                ],
              ),
            ),

            // Padding
            const SizedBox(height: 30),

            // --- Conditionally Display Active Group Colors ---
            // if (_isInGroup && !_isLoading && _userColors.isNotEmpty)
              ActiveGroupColors(groupUsersColors: _userColors),

            // --- Completion Buttons (conditional) ---
            if (isPuzzleSolved) _buildCompletionButtons(),

            const SizedBox(height: 20), // Bottom padding
          ],
        ),
      ),
    );
  }

  Widget _buildColumnHeaders(double gridMargin) {
    return Row(
      children: List.generate(gridSize, (index) {
        return Expanded(
          child: Center(
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildRowHeaders(double headerWidth, double gridMargin) {
    return Padding(
      padding: EdgeInsets.fromLTRB(gridMargin, 0, 0, 0),
      child: Column(
        children: List.generate(gridSize, (index) {
          return Expanded(
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildActualGrid(double gridMargin, double cellSpacing) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        // Container for grid
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outline,
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
            width: 1,
          ),
        ),

        // Grid
        child: GridView.builder(
          // Grid properties
          padding: EdgeInsets.all(cellSpacing / 2),
          physics: const NeverScrollableScrollPhysics(),
          itemCount: gridSize * gridSize,

          // Grid layout
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: gridSize,
            mainAxisSpacing: cellSpacing,
            crossAxisSpacing: cellSpacing,
          ),
          itemBuilder: (context, index) {
            // Calculate row and column
            final row = index ~/ gridSize;
            final col = (gridSize - 1) - (index % gridSize);

            // Ensure valid indices before accessing data
            if (row >= 0 && row < gridSize && col >= 0 && col < gridSize) {
              final cell = gridCellData[row][col];
              final GlobalKey cellKey = gridKeys[row][col];

              // --- Cell Content ---

              Widget cellContent;
              if (cell.isBlackSquare) {
                cellContent = Container(color: Colors.black);
              } else {
                cellContent = Container(
                  decoration: BoxDecoration(color: cell.displayColor),
                  alignment: Alignment.center,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      double size = constraints.biggest.shortestSide * 0.6;
                      return Text(
                        cell.enteredChar,
                        style: TextStyle(
                          fontSize: size.clamp(8.0, 24.0),
                          color: getContrastColor(cell.displayColor),
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                      );
                    },
                  ),
                );
              }

              // --- Cell Wrapper with Gesture Detection ---

              return GestureDetector(
                key: cellKey,
                onPanStart: (details) => _onPanStart(details, row, col),
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: cellContent,
              );
            } else {
              // Error indicator
              return Container(color: Colors.red);
            }
          },
        ),
      ),
    );
  }

  Widget _buildCompletionButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Back button
        ElevatedButton.icon(
          icon: Icon(Icons.arrow_back_ios, size: 16, color: Colors.black),
          label: Text(
            "الرجوع إلى القائمة",
            style: TextStyle(
              fontSize: 16,
              color: Colors.black,
              fontFamily: 'Cairo',
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          ),
          onPressed: () => Navigator.pop(context), // Go back to previous screen
        ),
      ],
    );
  }
}

/// Determines a contrasting text color (black or white) for a given background color.
Color getContrastColor(Color backgroundColor) {
  // Calculate luminance (0.0 black to 1.0 white)
  double luminance = backgroundColor.computeLuminance();
  // Use white text on dark backgrounds and black text on light backgrounds
  return luminance > 0.5 ? Colors.black : Colors.white;
}
