// Flutter imports
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Local imports
import 'package:crosswords/Logic/cell_model.dart';
import 'package:crosswords/Settings/firebase_service.dart';

// ========== Animated Popup ========== //

class AnimatedPopup extends StatefulWidget {
  final List<CellModel> cellsToAnimate;
  final AnimationController animationController;
  final String direction;
  final String clueText;
  final String wordSolution;
  final Function(Map<int, String>) onSubmitOrDismiss;
  final Color initialCellColor;
  final Color correctCellColor;
  final Color errorCellColor;

  const AnimatedPopup({
    super.key,
    required this.cellsToAnimate,
    required this.animationController,
    required this.direction,
    required this.clueText,
    required this.wordSolution,
    required this.onSubmitOrDismiss,
    required this.initialCellColor,
    required this.correctCellColor,
    required this.errorCellColor,
  });

  @override
  AnimatedPopupState createState() => AnimatedPopupState();
}

class AnimatedPopupState extends State<AnimatedPopup> {
  // ===== State variables ===== //
  late List<FocusNode> _cellFocusNodes;
  late List<TextEditingController> _cellTextControllers;
  late List<String> _currentEnteredChars;
  late List<Color> _currentCellColors;
  late List<bool> _cellsLocked;
  bool _suppressListener = false;

  // Firebase & Syncing
  late final FirebaseService _firebaseService;
  Map<String, String> _userColors = {};
  Timer? _updateTimer;

  // State for "Reversed" feature
  bool _isReversable = false;
  bool _isReversed = false;

  // --- Lifecycle and State Management ---

  @override
  void initState() {
    super.initState();
    _firebaseService = FirebaseService();

    // "Reversable" logic applies to any clue with the magic word.
    _isReversable = widget.clueText.contains("معكوسة");

    int cellCount = widget.cellsToAnimate.length;
    _cellTextControllers = List.generate(
      cellCount,
      (i) => TextEditingController(text: widget.cellsToAnimate[i].enteredChar),
    );
    _cellFocusNodes = List.generate(cellCount, (i) => FocusNode());
    _currentEnteredChars =
        widget.cellsToAnimate.map((c) => c.enteredChar).toList();
    _cellsLocked =
        widget.cellsToAnimate.map((c) => c.isCurrentCharCorrect).toList();
    _currentCellColors = List.filled(cellCount, widget.initialCellColor);

    widget.animationController.addStatusListener(_onAnimationStatusChanged);
    for (int i = 0; i < cellCount; i++) {
      _cellTextControllers[i].addListener(() => _onCellTextChanged(i));
    }

    _loadUserColorsAndSetCellColors();
    _startPeriodicUpdates();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    widget.animationController.removeStatusListener(_onAnimationStatusChanged);
    for (var controller in _cellTextControllers) {
      controller.dispose();
    }
    for (var focusNode in _cellFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  // --- Data and Syncing ---

  void _startPeriodicUpdates() {
    _updateTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted) _checkForExternalUpdates();
    });
  }

  void _checkForExternalUpdates() {
    if (!mounted) return;
    bool hasUpdates = false;
    for (int i = 0; i < widget.cellsToAnimate.length; i++) {
      final cell = widget.cellsToAnimate[i];
      if (cell.isCurrentCharCorrect && !_cellsLocked[i]) {
        _updateAndLockCell(i, cell.enteredChar);
        hasUpdates = true;
      }
    }
    if (hasUpdates && mounted) setState(() {});
  }

  void _loadUserColorsAndSetCellColors() async {
    final prefs = await SharedPreferences.getInstance();
    final groupName = prefs.getString('groupName');
    if (groupName != null) {
      final users = await _firebaseService.getGroupUsers(groupName);
      _userColors = Map<String, String>.fromEntries(
        users.entries.map((e) => MapEntry(e.key, e.value.toString())),
      );
    }
    if (mounted) {
      setState(() {
        for (int i = 0; i < widget.cellsToAnimate.length; i++) {
          _updateCellColor(i);
        }
      });
    }
  }

  // --- Event Handlers ---

  void _onAnimationStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      Future.delayed(const Duration(milliseconds: 50), () {
        if (!mounted) return;
        int focusIdx = _cellsLocked.indexWhere((locked) => !locked);
        if (focusIdx == -1) focusIdx = 0;

        if (focusIdx < _cellFocusNodes.length && !_cellsLocked[focusIdx]) {
          _cellFocusNodes[focusIdx].requestFocus();
          _cellTextControllers[focusIdx].selectAll();
        }
      });
    }
  }

  void _onCellTextChanged(int index) {
    if (_suppressListener) return;

    final newChar = _cellTextControllers[index].text;
    _currentEnteredChars[index] = newChar;

    setState(() => _updateCellColor(index));

    if (newChar.isNotEmpty &&
        _currentEnteredChars[index] ==
            widget.cellsToAnimate[index].solutionChar) {
      _cellsLocked[index] = true;
      _handleAutoAdvance(index);
    }
  }

  void _handleAutoAdvance(int currentIndex) {
    int nextIndex;
    if (_isReversed) {
      nextIndex = _cellsLocked.lastIndexWhere(
        (locked) => !locked,
        currentIndex - 1,
      );
    } else {
      nextIndex = _cellsLocked.indexWhere(
        (locked) => !locked,
        currentIndex + 1,
      );
    }

    if (nextIndex != -1) {
      _cellFocusNodes[nextIndex].requestFocus();
      _cellTextControllers[nextIndex].selectAll();
    } else {
      _handleDismissOrSubmit();
    }
  }

  void _handleDismissOrSubmit() {
    if (!mounted) return;
    Map<int, String> result = {};
    for (int i = 0; i < widget.cellsToAnimate.length; i++) {
      result[widget.cellsToAnimate[i].animationIndex] = _currentEnteredChars[i];
    }
    widget.onSubmitOrDismiss(result);
  }

  // --- Helpers ---

  void _updateAndLockCell(int index, String char) {
    _cellsLocked[index] = true;
    _currentEnteredChars[index] = char;
    _suppressListener = true;
    _cellTextControllers[index].text = char;
    _suppressListener = false;
    _updateCellColor(index);
  }

  void _updateCellColor(int index) {
    String char = _currentEnteredChars[index];
    if (char.isEmpty) {
      _currentCellColors[index] = widget.initialCellColor;
      return;
    }
    if (char == widget.cellsToAnimate[index].solutionChar) {
      final madeBy = widget.cellsToAnimate[index].madeBy.trim();
      final colorHex = _userColors[madeBy];
      if (madeBy.isNotEmpty && colorHex != null) {
        _currentCellColors[index] = Color(
          int.parse(colorHex.replaceFirst('#', '0xff')),
        );
      } else {
        _currentCellColors[index] = widget.correctCellColor;
      }
    } else {
      _currentCellColors[index] = widget.errorCellColor;
    }
  }

  Color _getContrastColor(Color backgroundColor) {
    return backgroundColor.computeLuminance() > 0.5
        ? Colors.black87
        : Colors.white;
  }

  // ===== Build Method & UI Helpers ===== //

  @override
  Widget build(BuildContext context) {
    if (widget.cellsToAnimate.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _handleDismissOrSubmit(),
      );
      return const SizedBox.shrink();
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _handleDismissOrSubmit();
      },
      child: AnimatedBuilder(
        animation: widget.animationController,
        builder: (context, child) {
          return Stack(
            children: [_buildBackground(context), ..._buildContent(context)],
          );
        },
      ),
    );
  }

  Widget _buildBackground(BuildContext context) {
    final blurAnimation = Tween<double>(begin: 0.0, end: 5.0).animate(
      CurvedAnimation(
        parent: widget.animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    return Positioned.fill(
      child: GestureDetector(
        onTap: _handleDismissOrSubmit,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: blurAnimation.value,
            sigmaY: blurAnimation.value,
          ),
          child: Container(
            color: Colors.black.withValues(alpha:
              0.3 * widget.animationController.value,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildContent(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double cellSize = widget.cellsToAnimate.first.originalRect.width;
    const double cellSpacing = 4.0;

    final double totalWidth =
        widget.cellsToAnimate.length * (cellSize + cellSpacing) - cellSpacing;
    final double startX = (screenSize.width - totalWidth) / 2;
    final double startY = (screenSize.height - cellSize) / 2.5;

    final cluePanel = Positioned(
      top: startY - 200,
      left: 20,
      right: 20,
      child: Opacity(
        opacity: widget.animationController.value,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildClueText(context),
            if (_isReversable) _buildReverseButton(context),
          ],
        ),
      ),
    );

    final animatedCellWidgets = List.generate(widget.cellsToAnimate.length, (
      index,
    ) {
      final cellData = widget.cellsToAnimate[index];
      final originalRect = cellData.originalRect;

      final int placementIndex =
          _isReversed
              ? cellData.animationIndex
              : (widget.cellsToAnimate.length - 1 - cellData.animationIndex);

      final targetX = startX + (placementIndex * (cellSize + cellSpacing));
      final targetY = startY;

      final targetPosition = Offset(targetX, targetY);

      final currentPosition =
          Offset.lerp(
            Offset(originalRect.left, originalRect.top),
            targetPosition,
            widget.animationController.value,
          )!;

      return Positioned(
        left: currentPosition.dx,
        top: currentPosition.dy,
        width: originalRect.width,
        height: originalRect.height,
        child: _buildInputCell(index),
      );
    });

    return [cluePanel, ...animatedCellWidgets];
  }

  Widget _buildClueText(BuildContext context) {
    return Card(
      elevation: 4 * widget.animationController.value,
      color: Theme.of(context).colorScheme.surface.withValues(alpha:0.85),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          widget.clueText,
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildReverseButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: TextButton.icon(
        icon: const Icon(Icons.swap_horiz),
        label: const Text("إعادة ترتيب"),
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          backgroundColor: Theme.of(
            context,
          ).colorScheme.surface.withValues(alpha:0.8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () {
          setState(() {
            _isReversed = !_isReversed;
          });
        },
      ),
    );
  }

  Widget _buildInputCell(int index) {
    final bool hasFocus = _cellFocusNodes[index].hasFocus;
    final double scale = 1.0 + (0.1 * widget.animationController.value);

    return Transform.scale(
      scale: scale,
      child: Container(
        decoration: BoxDecoration(
          color: _currentCellColors[index],
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color:
                  hasFocus
                      ? Theme.of(context).primaryColor.withValues(alpha:0.7)
                      : Colors.black.withValues(alpha:
                        0.3 * widget.animationController.value,
                      ),
              blurRadius: hasFocus ? 8 : 5 * widget.animationController.value,
              spreadRadius: hasFocus ? 2 : 0,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Material(
          type: MaterialType.transparency,
          child: LayoutBuilder(
            builder: (context, constraints) {
              double fontSize = (constraints.maxWidth * 0.6).clamp(12.0, 50.0);
              return TextField(
                controller: _cellTextControllers[index],
                focusNode: _cellFocusNodes[index],
                enabled: !_cellsLocked[index],
                textAlign: TextAlign.center,
                maxLength: 1,
                maxLengthEnforcement: MaxLengthEnforcement.none,
                onChanged: (value) {
                  if (value.isNotEmpty) {
                    if (value.isNotEmpty) {
                      final char = value.characters.last;
                      _suppressListener = true;
                      _cellTextControllers[index].value = TextEditingValue(
                        text: char,
                        selection: TextSelection(
                          baseOffset: 0,
                          extentOffset: char.length,
                        ),
                      );
                      _suppressListener = false;
                    }
                  }
                },
                style: TextStyle(
                  color: _getContrastColor(_currentCellColors[index]),
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  counterText: "",
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
                cursorColor: _getContrastColor(_currentCellColors[index]),
                textInputAction:
                    (index == widget.cellsToAnimate.length - 1)
                        ? TextInputAction.done
                        : TextInputAction.next,
                onSubmitted: (_) => _handleAutoAdvance(index),
              );
            },
          ),
        ),
      ),
    );
  }
}

extension SelectAllExtension on TextEditingController {
  void selectAll() {
    // A small delay ensures the framework has processed the focus change
    // before we try to set the selection.
    Future.microtask(() {
      if (text.isNotEmpty) {
        selection = TextSelection(baseOffset: 0, extentOffset: text.length);
      }
    });
  }
}
