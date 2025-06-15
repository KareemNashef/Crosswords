// lib/Logic/game_grid.dart

// Flutter imports
import 'dart:async';
import 'dart:convert';
import 'dart:math' show Point;
// For ImageFilter.blur
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

// Local imports
import 'package:crosswords/Logic/animated_popup.dart';
import 'package:crosswords/Logic/cell_model.dart';
import 'package:crosswords/Logic/clue_model.dart';
import 'package:crosswords/Logic/game_grid_ui.dart'; // Import the new UI file
import 'package:crosswords/Settings/firebase_service.dart';
import 'package:crosswords/Utilities/color_utils.dart';

class GameGrid extends StatefulWidget {
  final String puzzleNumber;
  const GameGrid({super.key, required this.puzzleNumber});

  @override
  GameGridState createState() => GameGridState();
}

class GameGridState extends State<GameGrid> with TickerProviderStateMixin {
  // All the state variables and logic methods remain here...
  // ...

  // ===== Class variables =====

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

  // Firebase service
  late final FirebaseService _firebaseService;
  String _currentGroupName = '';
  String _currentUserName = '';
  bool _isInGroup = false;
  StreamSubscription? _puzzleSubscription;
  Map<String, String> _userColors = {};
  final Map<String, int> _userScores = {};
  final Map<String, bool> _userActive = {};
  
  // --- Core Game Logic (Unchanged) ---

  @override
  void initState() {
    super.initState();
    _firebaseService = FirebaseService();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    startActiveUserUpdates();
    _initializeGame();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_colorsInitialized) {
      _initializeColors();
    }
  }

  @override
  void dispose() {
    activeUserTimer?.cancel();
    _animationController.dispose();
    _puzzleSubscription?.cancel();
    super.dispose();
  }

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
    final users = await _firebaseService.getGroupUsers(_currentGroupName);
    if (mounted) {
      _userColors = Map<String, String>.fromEntries(
        users.entries.map((e) => MapEntry(e.key, e.value.toString())),
      );
    }
  }

  Future<void> _initializeColors() async {
    if (_colorsInitialized) return;
    final prefs = await SharedPreferences.getInstance();
    final theme = Theme.of(context);
    _initialCellColor = theme.colorScheme.surface.withValues(alpha:0.6);
    _errorCellColor = theme.colorScheme.errorContainer;
    _selectionCellColor = theme.colorScheme.tertiaryContainer;
    final savedColorHex = prefs.getString('selectedColor');
    if (savedColorHex != null && savedColorHex.startsWith('#')) {
      _correctCellColor = hexStringToColor(savedColorHex);
    } else {
      _correctCellColor = theme.colorScheme.primaryContainer;
    }
    _colorsInitialized = true;
    if (gridCellData.isNotEmpty) {
      _reapplyAllCellColors();
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadPuzzleDataAndProgress() async {
    if (!_colorsInitialized) {
      await _initializeColors();
    }
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      await _loadPuzzleStructure();
      await _loadInitialProgress();
      if (mounted) {
        _reapplyAllCellColors();
        isPuzzleSolved = _checkIfPuzzleCompleteLocally();
      }
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadPuzzleStructure() async {
    final solutionJsonString = await rootBundle.loadString(
      'assets/Puzzles/puzzle_${widget.puzzleNumber}_solution.json',
    );
    final List<dynamic> decodedSolutionsRaw = json.decode(solutionJsonString);
    final List<List<String>> solutionGrid =
        decodedSolutionsRaw.map((row) => List<String>.from(row)).toList();
    if (solutionGrid.isEmpty) throw Exception("Solution grid is empty");
    gridSize = solutionGrid.length;
    _initializeGridCells(solutionGrid);
    _initializeKeys();
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
    _assignCluesToCells();
  }

  void _initializeGridCells(List<List<String>> solutionGrid) {
    Color tempInitialColor = _colorsInitialized ? _initialCellColor : Colors.grey.shade300;
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
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        gridCellData[r][c].acrossClue = null;
        gridCellData[r][c].acrossBlockIndex = null;
        gridCellData[r][c].downClue = null;
        gridCellData[r][c].downBlockIndex = null;
      }
    }
    for (final clue in allParsedClues) {
      for (int blockIdx = 0; blockIdx < clue.blockSolutions.length; blockIdx++) {
        Point<int> startCoord = clue.blockStartCoords[blockIdx];
        int length = clue.blockLengths[blockIdx];
        for (int i = 0; i < length; i++) {
          int r = startCoord.x;
          int c = startCoord.y;
          if (clue.direction == "horizontal") {
            gridCellData[r][c + i].acrossClue = clue;
            gridCellData[r][c + i].acrossBlockIndex = blockIdx;
          } else {
            gridCellData[r + i][c].downClue = clue;
            gridCellData[r + i][c].downBlockIndex = blockIdx;
          }
        }
      }
    }
  }

  Future<void> _loadInitialProgress() async {
    Map<String, dynamic>? progressData;
    bool loadedFromFirebase = false;
    if (_isInGroup && _currentGroupName.isNotEmpty) {
      progressData = await _firebaseService.streamPuzzleProgress(_currentGroupName, widget.puzzleNumber).first;
      if (progressData.isNotEmpty) loadedFromFirebase = true;
    }
    if (!loadedFromFirebase) {
      final prefs = await SharedPreferences.getInstance();
      final savedProgressJson = prefs.getString('puzzle_progress_${widget.puzzleNumber}');
      if (savedProgressJson != null) {
        try {
          progressData = jsonDecode(savedProgressJson);
          if (_isInGroup && _currentGroupName.isNotEmpty && progressData != null && progressData.isNotEmpty) {
            await _syncLocalMapToFirebase(progressData);
          }
        } catch (e) {
          progressData = null;
        }
      }
    }
    if (progressData != null && progressData.isNotEmpty) {
      _applyRemotePuzzleProgress(progressData, isInitialLoad: true);
    }
  }

  void _subscribeToPuzzleUpdates() {
    if (!_isInGroup || _currentGroupName.isEmpty || widget.puzzleNumber.isEmpty) return;
    _puzzleSubscription?.cancel();
    _puzzleSubscription = _firebaseService.streamPuzzleProgress(_currentGroupName, widget.puzzleNumber).listen((progressData) {
      if (mounted && gridCellData.isNotEmpty && _colorsInitialized) {
        _applyRemotePuzzleProgress(progressData);
      }
    });
  }

  void _applyRemotePuzzleProgress(Map<String, dynamic> progressData, {bool isInitialLoad = false}) {
    bool needsUIUpdate = false;
    bool remoteReportsDone = progressData['progress'] == 'Done';
    progressData.forEach((key, value) {
      if (key == 'progress') return;
      final parts = key.split('_');
      if (parts.length != 2) return;
      final r = int.tryParse(parts[0]);
      final c = int.tryParse(parts[1]);
      if (r != null && c != null && r < gridSize && c < gridSize) {
        final cell = gridCellData[r][c];
        if (cell.isBlackSquare) return;
        String remoteChar = value['char'] ?? '';
        String remoteMadeBy = value['madeBy'] ?? '';
        if (cell.enteredChar != remoteChar || cell.madeBy != remoteMadeBy) {
          cell.enteredChar = remoteChar;
          cell.madeBy = remoteMadeBy;
          _updateCellColor(cell);
          needsUIUpdate = true;
        }
      }
    });
    bool isNowLocallyComplete = _checkIfPuzzleCompleteLocally();
    if (isPuzzleSolved != isNowLocallyComplete) {
      if (isNowLocallyComplete || remoteReportsDone) {
        if (!isPuzzleSolved) {
          isPuzzleSolved = true;
          needsUIUpdate = true;
          if (isNowLocallyComplete && !remoteReportsDone && _isInGroup) {
            _updateFirebaseProgressMetadata("Done");
          }
        }
      } else {
        if (isPuzzleSolved) {
          isPuzzleSolved = false;
          needsUIUpdate = true;
          if (remoteReportsDone && _isInGroup) {
            _updateFirebaseProgressMetadata("In Progress");
          }
        }
      }
    }
    if (needsUIUpdate && mounted) {
      setState(() {});
    }
  }

  Future<void> _syncCellChangeToFirebase(int r, int c, String char, String madeBy) async {
    if (!_isInGroup || _currentGroupName.isEmpty || _currentUserName.isEmpty) return;
    await _firebaseService.updatePuzzleCell(_currentGroupName, widget.puzzleNumber, r, c, char, madeBy);
  }
  
  Future<void> _syncLocalMapToFirebase(Map<String, dynamic> progressMap) async {
    if (!_isInGroup || _currentGroupName.isEmpty) return;
    await _firebaseService.updatePuzzleProgressBatch(_currentGroupName, widget.puzzleNumber, progressMap);
  }

  Future<void> _updateFirebaseProgressMetadata(String status) async {
    if (!_isInGroup || _currentGroupName.isEmpty) return;
    await _firebaseService.updatePuzzleMetadata(_currentGroupName, widget.puzzleNumber, {'progress': status});
  }

  Timer? activeUserTimer;
  void startActiveUserUpdates() {
    activeUserTimer?.cancel();
    activeUserTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_currentUserName.isEmpty || _currentGroupName.isEmpty) return;
      await _firebaseService.updateActiveUser(_currentGroupName, widget.puzzleNumber, _currentUserName);
      final doc = await _firebaseService.getPuzzleDoc(_currentGroupName, widget.puzzleNumber);
      final data = doc.data();
      final activeMap = data?['active'] as Map<String, dynamic>? ?? {};
      final now = DateTime.now();
      _userActive.clear();
      activeMap.forEach((user, timestamp) {
        final lastActive = DateTime.tryParse(timestamp ?? '');
        _userActive[user] = lastActive != null && now.difference(lastActive).inSeconds <= 5;
      });
      if (mounted) setState(() {});
    });
  }

  void _solvePuzzle() {
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        final cell = gridCellData[r][c];
        if (cell.isBlackSquare) continue;
        if (cell.enteredChar != cell.solutionChar) {
          cell.enteredChar = cell.solutionChar;
          _updateCellColor(cell);
          _syncCellChangeToFirebase(r, c, cell.solutionChar, _currentUserName);
        }
      }
    }
    if (!isPuzzleSolved) isPuzzleSolved = true;
    if (_isInGroup) _updateFirebaseProgressMetadata("Done");
    _savePuzzleProgressLocally();
    setState(() {});
  }

  Future<void> _savePuzzleProgressLocally() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> progressData = {};
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        final cell = gridCellData[r][c];
        if (!cell.isBlackSquare && cell.enteredChar.isNotEmpty) {
          progressData['${r}_$c'] = {'char': cell.enteredChar, 'madeBy': cell.madeBy};
        }
      }
    }
    isPuzzleSolved = _checkIfPuzzleCompleteLocally();
    final String currentStatus = isPuzzleSolved ? "Done" : "In Progress";
    progressData['progress'] = currentStatus;
    await prefs.setString('puzzle_progress_${widget.puzzleNumber}', jsonEncode(progressData));
    if (_isInGroup) {
      _updateFirebaseProgressMetadata(currentStatus);
    }
    if (isPuzzleSolved && mounted) {
      setState(() {});
    }
  }

  bool _checkIfPuzzleCompleteLocally() {
    if (gridCellData.isEmpty) return false;
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        final cell = gridCellData[r][c];
        if (!cell.isBlackSquare && !cell.isCurrentCharCorrect) return false;
      }
    }
    return true;
  }

  Future<void> _resetPuzzle() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إعادة ضبط اللغز؟', textDirection: TextDirection.rtl),
        content: const Text('هل أنت متأكد أنك تريد مسح كل التقدم لهذا اللغز؟', textDirection: TextDirection.rtl),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('إعادة الضبط')),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;
    setState(() => _isLoading = true);
    isPuzzleSolved = false;
    activeClue = null;
    _clearSelectionHighlight(forceUpdate: false);
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        if (!gridCellData[r][c].isBlackSquare) {
          gridCellData[r][c].enteredChar = '';
          gridCellData[r][c].madeBy = '';
        }
      }
    }
    _reapplyAllCellColors();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('puzzle_progress_${widget.puzzleNumber}');
    if (_isInGroup && _currentGroupName.isNotEmpty) {
      await _firebaseService.resetPuzzleProgress(_currentGroupName, widget.puzzleNumber);
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _calculateScores() {
    // **THE FIX**: Add a guard clause at the beginning. If the grid isn't
    // populated yet, clear the scores and exit the method immediately.
    if (gridCellData.isEmpty) {
      _userScores.clear();
      return;
    }

    // Clear scores
    _userScores.clear();

    // Iterate over grid (this is now safe)
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        final cell = gridCellData[r][c];
        if (cell.isBlackSquare) continue;

        if (cell.isCurrentCharCorrect) {
          if (cell.madeBy.isNotEmpty) {
            _userScores[cell.madeBy] = (_userScores[cell.madeBy] ?? 0) + 1;
          }
        }
      }
    }
  }

  void _updateCellColor(CellModel cell) {
    if (!_colorsInitialized) return;
    if (cell.isBlackSquare) {
      cell.displayColor = Colors.black;
    } else if (originalHighlightColors.containsKey(cell)) {
      cell.displayColor = _selectionCellColor;
    } else if (cell.enteredChar.isEmpty) {
      cell.displayColor = _initialCellColor;
    } else {
      if (cell.isCurrentCharCorrect) {
        if (_isInGroup && cell.madeBy.isNotEmpty && _userColors.containsKey(cell.madeBy)) {
          final hexColor = _userColors[cell.madeBy]!;
          try {
            cell.displayColor = hexStringToColor(hexColor);
          } catch (e) {
            cell.displayColor = _correctCellColor;
          }
        } else {
          cell.displayColor = _correctCellColor;
        }
      } else {
        cell.displayColor = _errorCellColor;
      }
    }
  }
  
  void _reapplyAllCellColors() {
    if (!_colorsInitialized || gridCellData.isEmpty) return;
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        if (!gridCellData[r][c].isBlackSquare) {
          _updateCellColor(gridCellData[r][c]);
        }
      }
    }
  }

  Rect? _getCellRect(int row, int col) {
    if (row < 0 || row >= gridSize || col < 0 || col >= gridSize || gridKeys.isEmpty) return null;
    final context = gridKeys[row][col].currentContext;
    if (context == null) return null;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final position = box.localToGlobal(Offset.zero);
    return Rect.fromLTWH(position.dx, position.dy, box.size.width, box.size.height);
  }

  void _handleSwipe(int r, int c, String swipeGestureDirection) {
    if (isAnimating || gridCellData[r][c].isBlackSquare) return;
    CellModel swipedCell = gridCellData[r][c];
    Clue? targetClue;
    int? targetBlockIndex;
    String? targetDirection;
    if (swipeGestureDirection == 'left' && swipedCell.acrossClue != null) {
      targetDirection = "horizontal";
      targetClue = swipedCell.acrossClue;
      targetBlockIndex = swipedCell.acrossBlockIndex;
    } else if (swipeGestureDirection == 'down' && swipedCell.downClue != null) {
      targetDirection = "vertical";
      targetClue = swipedCell.downClue;
      targetBlockIndex = swipedCell.downBlockIndex;
    } else {
      return;
    }
    _clearSelectionHighlight();
    activeClue = targetClue;
    activeBlockIndexInClue = targetBlockIndex;
    activeDirection = targetDirection;
    cellsToAnimate.clear();
    Point<int> startCoord = activeClue!.blockStartCoords[activeBlockIndexInClue!];
    int length = activeClue!.blockLengths[activeBlockIndexInClue!];
    List<CellModel> wordCells = [];
    for (int i = 0; i < length; i++) {
      int currentR = (activeDirection == "vertical") ? startCoord.x + i : startCoord.x;
      int currentC = (activeDirection == "horizontal") ? startCoord.y + i : startCoord.y;
      if (currentR < gridSize && currentC < gridSize) wordCells.add(gridCellData[currentR][currentC]);
    }
    final bool isAppRTL = Directionality.of(context) == TextDirection.rtl;
    if (activeDirection == "horizontal" && isAppRTL) wordCells = wordCells.reversed.toList();
    int animationIndex = 0;
    for (final cell in wordCells) {
      final rect = _getCellRect(cell.row, cell.col);
      if (rect != null) {
        originalHighlightColors[cell] = cell.displayColor;
        cell.displayColor = _selectionCellColor;
        cell.originalRect = rect;
        cell.animationIndex = animationIndex++;
        cellsToAnimate.add(cell);
      }
    }
    if (cellsToAnimate.isNotEmpty) {
      setState(() {});
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && !isAnimating && activeClue == targetClue) {
          _showAnimatedPopup();
        } else if (mounted) {
          _clearSelectionHighlight();
        }
      });
    } else {
      _clearSelectionHighlight();
    }
  }

  void _clearSelectionHighlight({bool forceUpdate = true}) {
    if (originalHighlightColors.isNotEmpty) {
      final cellsToUpdate = originalHighlightColors.keys.toList();
      originalHighlightColors.clear();
      for (final cell in cellsToUpdate) {
        _updateCellColor(cell);
      }
      if (forceUpdate && mounted) {
        setState(() {});
      }
    }
  }

  void _showAnimatedPopup() {
    if (!mounted || !_colorsInitialized || cellsToAnimate.isEmpty || activeClue == null) {
      _clearSelectionHighlight();
      return;
    }
    setState(() => isAnimating = true);
    _animationController.forward(from: 0.0);
    final String currentClueText = activeClue!.clueTexts[activeBlockIndexInClue!];
    final String currentWordSolution = activeClue!.blockSolutions[activeBlockIndexInClue!];
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder: (BuildContext context) {
        return AnimatedPopup(
          cellsToAnimate: cellsToAnimate,
          animationController: _animationController,
          direction: activeDirection!,
          clueText: currentClueText,
          wordSolution: currentWordSolution,
          initialCellColor: _initialCellColor,
          correctCellColor: _correctCellColor,
          errorCellColor: _errorCellColor,
          onSubmitOrDismiss: (Map<int, String> enteredCharsMap) {
            bool changed = false;
            for (final cell in cellsToAnimate) {
              String? enteredForThisCell = enteredCharsMap[cell.animationIndex];
              if (enteredForThisCell != null) {
                if (cell.enteredChar != cell.solutionChar) {
                  if (cell.enteredChar != enteredForThisCell) {
                    cell.enteredChar = enteredForThisCell;
                    cell.madeBy = _currentUserName;
                    _updateCellColor(cell);
                    _syncCellChangeToFirebase(cell.row, cell.col, cell.enteredChar, cell.madeBy);
                    changed = true;
                  }
                }
              }
            }
            if (changed) _savePuzzleProgressLocally();
            if (Navigator.canPop(context)) Navigator.of(context).pop();
          },
        );
      },
    ).whenComplete(() {
      _clearSelectionHighlight();
      _animationController.reverse().whenComplete(() {
        if (mounted) setState(() => isAnimating = false);
      });
    });
  }

  void _onPanStart(DragStartDetails details, int row, int col) {
    if (isAnimating || gridCellData[row][col].isBlackSquare) return;
    _swipeStartPosition = details.globalPosition;
    _swipeCellRow = row;
    _swipeCellCol = col;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_swipeStartPosition == null || isAnimating) return;
    if (gridCellData[_swipeCellRow!][_swipeCellCol!].isBlackSquare) {
      _resetSwipeTracking();
      return;
    }
    final dx = details.globalPosition.dx - _swipeStartPosition!.dx;
    final dy = details.globalPosition.dy - _swipeStartPosition!.dy;
    const double swipeThreshold = 25.0;
    if (dx.abs() > swipeThreshold || dy.abs() > swipeThreshold) {
      String swipeDir = "";
      if (dx.abs() > dy.abs()) {
        swipeDir = (dx < 0) ? 'left' : 'right';
      } else {
        swipeDir = (dy > 0) ? 'down' : 'up';
      }
      if (swipeDir == 'left' || swipeDir == 'down') {
        _handleSwipe(_swipeCellRow!, _swipeCellCol!, swipeDir);
      }
      _resetSwipeTracking();
    }
  }

  void _onPanEnd(DragEndDetails details) => _resetSwipeTracking();
  void _resetSwipeTracking() {
    _swipeStartPosition = null;
    _swipeCellRow = null;
    _swipeCellCol = null;
  }

  // --- Build Method ---

  @override
  Widget build(BuildContext context) {
    _calculateScores(); // Recalculate scores on each build

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.secondaryContainer,
            Theme.of(context).colorScheme.tertiaryContainer,
          ],
        ),
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.transparent,
        appBar: _buildAppBar(),
        // Delegate the body to the new UI widget
        body: GameGridUI(
          gridSize: gridSize,
          isLoading: _isLoading || !_colorsInitialized,
          isPuzzleSolved: isPuzzleSolved,
          isInGroup: _isInGroup,
          gridCellData: gridCellData,
          gridKeys: gridKeys,
          userColors: _userColors,
          userScores: _userScores,
          userActive: _userActive,
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          onBackToMenu: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).pop(),
        color: Theme.of(context).colorScheme.primary,
      ),
      centerTitle: true,
      title: Text(
        'لغز رقم ${widget.puzzleNumber}',
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.primary),
          tooltip: 'إعادة ضبط اللغز',
          onPressed: _isLoading ? null : _resetPuzzle,
        ),
        if (_currentUserName == "هعهع" || _currentUserName == "بوتيتو")
          IconButton(
            icon: Icon(Icons.check_circle_outline, color: Theme.of(context).colorScheme.primary),
            tooltip: 'حل اللغز',
            onPressed: _isLoading ? null : _solvePuzzle,
          ),
        const SizedBox(width: 8),
      ],
    );
  }
}