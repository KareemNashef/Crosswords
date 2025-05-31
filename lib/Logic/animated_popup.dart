// Flutter imports
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:crosswords/Settings/firebase_service.dart';
import 'dart:async';

// Local imports
import 'package:crosswords/Logic/cell_model.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ========== Animated Popup ========== //

class AnimatedPopup extends StatefulWidget {
  // ===== Class variables ===== //

  final List<CellModel> cellsToAnimate;
  final AnimationController animationController;
  final String direction;
  final String clueText;
  final String wordSolution;
  final Function(Map<int, String>) onSubmitOrDismiss;
  final Color initialCellColor;
  final Color correctCellColor;
  final Color errorCellColor;

  // Constructor
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
  // ===== Class variables ===== //

  // State variables
  late List<FocusNode> _cellFocusNodes;
  late List<String> _currentEnteredChars;
  late List<Color> _currentCellColors;
  late List<bool> _cellsLocked; // Track which cells are locked
  bool _suppressListener = false;

  // Controllers
  late List<TextEditingController> _cellTextControllers;

  // Firebase service
  late final FirebaseService _firebaseService;
  Map<String, String> _userColors = {};

  // Timer for periodic updates
  Timer? _updateTimer;

  // ===== Class methods ===== //

  @override
  void initState() {
    super.initState();
    _firebaseService = FirebaseService();

    _cellTextControllers = List.generate(
      widget.cellsToAnimate.length,
      (index) =>
          TextEditingController(text: widget.cellsToAnimate[index].enteredChar),
    );
    _cellFocusNodes = List.generate(
      widget.cellsToAnimate.length,
      (index) => FocusNode(),
    );

    _currentEnteredChars =
        widget.cellsToAnimate.map((c) => c.enteredChar).toList();

    // Initialize locked cells based on current state
    _cellsLocked = List.generate(
      widget.cellsToAnimate.length,
      (index) =>
          widget.cellsToAnimate[index].enteredChar ==
          widget.cellsToAnimate[index].solutionChar,
    );

    widget.animationController.addStatusListener(_onAnimationStatusChanged);
    for (int i = 0; i < _cellTextControllers.length; i++) {
      _cellTextControllers[i].addListener(() => _onCellTextChanged(i));
    }
    _currentCellColors = List.filled(
      widget.cellsToAnimate.length,
      widget.initialCellColor,
    );
    _loadUserColorsAndSetCellColors();

    // Start periodic updates to check for external changes
    _startPeriodicUpdates();
  }

  void _startPeriodicUpdates() {
    _updateTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted) {
        _checkForExternalUpdates();
      }
    });
  }

  void _checkForExternalUpdates() {
    if (!mounted) return;

    bool hasUpdates = false;

    for (int i = 0; i < widget.cellsToAnimate.length; i++) {
      final cell = widget.cellsToAnimate[i];

      // Only check for external changes if the current local value differs from the cell data
      // AND the cell data represents a correct solution
      if (cell.enteredChar == cell.solutionChar) {
        // Lock this cell and update its appearance
        _cellsLocked[i] = true;
        _currentEnteredChars[i] = cell.enteredChar;

        // Update controller WITHOUT triggering listener
        _suppressListener = true;
        _cellTextControllers[i].text = cell.enteredChar;
        _suppressListener = false;

        // Update color based on who made the entry
        final madeBy = cell.madeBy?.trim() ?? '';
        final colorHex = _userColors[madeBy];

        if (madeBy.isEmpty || _userColors.isEmpty || colorHex == null) {
          _currentCellColors[i] = widget.correctCellColor;
        } else {
          _currentCellColors[i] = Color(
            int.parse(colorHex.replaceFirst('#', '0xff')),
          );
        }

        hasUpdates = true;
      }
    }

    if (hasUpdates && mounted) {
      setState(() {});
    }
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

    setState(() {
      _currentCellColors =
          widget.cellsToAnimate.map((c) {
            if (c.enteredChar.isEmpty) return widget.initialCellColor;

            if (c.enteredChar != c.solutionChar) return widget.errorCellColor;

            final madeBy = c.madeBy?.trim() ?? '';
            final colorHex = _userColors[madeBy];

            if (madeBy.isEmpty || _userColors.isEmpty || colorHex == null) {
              return widget.correctCellColor;
            }

            return Color(int.parse(colorHex.replaceFirst('#', '0xff')));
          }).toList();
    });
  }

  // Animation listener - Fixed version
  void _onAnimationStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      // Add a small delay to ensure the TextField widgets are properly built
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted && _cellFocusNodes.isNotEmpty) {
          int focusIdx = _currentEnteredChars.indexWhere(
            (char) => char.isEmpty,
          );
          if (focusIdx == -1) {
            focusIdx = 0;
          }

          if (focusIdx >= 0 &&
              focusIdx < _cellFocusNodes.length &&
              !_cellsLocked[focusIdx]) {
            FocusScope.of(context).requestFocus(_cellFocusNodes[focusIdx]);
            _cellTextControllers[focusIdx].selection = TextSelection(
              baseOffset: 0,
              extentOffset: _cellTextControllers[focusIdx].text.length,
            );
          }
        }
      });
    }
  }

  // Text controller listener
  void _onCellTextChanged(int index) {
    if (_suppressListener) return;

    // Don't allow changes to locked cells
    if (_cellsLocked[index]) {
      // Restore the original text if someone tries to change a locked cell
      _cellTextControllers[index].text = _currentEnteredChars[index];
      _cellTextControllers[index].selection = TextSelection.fromPosition(
        TextPosition(offset: _currentEnteredChars[index].length),
      );
      return;
    }

    String newChar = _cellTextControllers[index].text;
    if (newChar.length > 1) {
      newChar = newChar.substring(newChar.length - 1);
      _cellTextControllers[index].text = newChar;
      _cellTextControllers[index].selection = TextSelection.fromPosition(
        TextPosition(offset: newChar.length),
      );
    }

    bool isCorrectEntry = false;

    // Update local state immediately
    _currentEnteredChars[index] = newChar;

    setState(() {
      if (newChar.isEmpty) {
        _currentCellColors[index] = widget.initialCellColor;
      } else {
        if (newChar == widget.cellsToAnimate[index].solutionChar) {
          // Lock this cell since it's now correct
          _cellsLocked[index] = true;

          final madeBy = widget.cellsToAnimate[index].madeBy?.trim() ?? '';
          final colorHex = _userColors[madeBy];

          if (madeBy.isEmpty || _userColors.isEmpty || colorHex == null) {
            _currentCellColors[index] = widget.correctCellColor;
          } else {
            _currentCellColors[index] = Color(
              int.parse(colorHex.replaceFirst('#', '0xff')),
            );
          }
          isCorrectEntry = true;
        } else {
          _currentCellColors[index] = widget.errorCellColor;
        }
      }
    });

    if (newChar.isNotEmpty && isCorrectEntry) {
      // Find next unlocked cell to focus
      int nextIndex = index + 1;
      while (nextIndex < _cellTextControllers.length &&
          _cellsLocked[nextIndex]) {
        nextIndex++;
      }

      if (nextIndex < _cellTextControllers.length) {
        FocusScope.of(context).requestFocus(_cellFocusNodes[nextIndex]);
        _cellTextControllers[nextIndex].selection = TextSelection(
          baseOffset: 0,
          extentOffset: _cellTextControllers[nextIndex].text.length,
        );
      }
    }
  }

  // Dispose
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

  // Contrast color
  Color _getContrastColor(Color backgroundColor) {
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  // Handle dismiss or submit
  void _handleDismissOrSubmit() {
    Map<int, String> result = {};
    for (int i = 0; i < widget.cellsToAnimate.length; i++) {
      result[widget.cellsToAnimate[i].animationIndex] = _currentEnteredChars[i];
    }
    widget.onSubmitOrDismiss(result);
  }

  // ===== Build method ===== //

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double centerX = screenSize.width / 2;
    final double centerY = screenSize.height / 2;

    final double potentialCellSize =
        widget.cellsToAnimate.isNotEmpty
            ? widget.cellsToAnimate.first.originalRect.width
            : 0.0;

    if (widget.cellsToAnimate.isEmpty || potentialCellSize <= 1.0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _handleDismissOrSubmit();
        }
      });
      return const SizedBox.shrink();
    }
    final double cellSize = potentialCellSize;

    final double cellSpacing = 4.0;

    final Animation<double> blurAnimation = Tween<double>(
      begin: 0.0,
      end: 3.5,
    ).animate(
      CurvedAnimation(
        parent: widget.animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        _handleDismissOrSubmit();
        return true;
      },
      child: AnimatedBuilder(
        animation: widget.animationController,
        builder: (context, child) {
          final totalAnimatedCellsWidth =
              widget.cellsToAnimate.length * (cellSize + cellSpacing) -
              cellSpacing;
          final startX = centerX - totalAnimatedCellsWidth / 2;

          final double clueTextTop = centerY / 2.5;

          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: _handleDismissOrSubmit,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: blurAnimation.value,
                      sigmaY: blurAnimation.value,
                    ),
                    child: Container(
                      // ignore: deprecated_member_use
                      color: Colors.black.withOpacity(
                        0.3 * widget.animationController.value,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                // Clue Text
                top: clueTextTop,
                left: 20,
                right: 20,
                child: Opacity(
                  opacity: widget.animationController.value,
                  child: Material(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),

                    child: Column(
                      children: [
                        SizedBox(height: 8),

                        Text(
                          widget.clueText,
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                blurRadius: 2.0,
                                color: Colors.black54,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
              ...List.generate(widget.cellsToAnimate.length, (index) {
                final cellData = widget.cellsToAnimate[index];
                final originalRect = cellData.originalRect;
                final int visualIndex = cellData.animationIndex;

                double targetX;
                if (widget.direction == "horizontal") {
                  targetX =
                      startX +
                      ((widget.cellsToAnimate.length - 1 - visualIndex) *
                          (cellSize + cellSpacing));
                } else {
                  targetX =
                      startX +
                      ((widget.cellsToAnimate.length - 1 - visualIndex) *
                          (cellSize + cellSpacing));
                }
                final targetPosition = Offset(targetX, centerY / 1.2);

                final currentPosition =
                    Offset.lerp(
                      Offset(originalRect.left, originalRect.top),
                      targetPosition,
                      widget.animationController.value,
                    )!;

                final scale = 1.0 + (0.1 * widget.animationController.value);
                return Positioned(
                  left: currentPosition.dx,
                  top: currentPosition.dy,
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: originalRect.width,
                      height: originalRect.height,
                      decoration: BoxDecoration(
                        border: Border.all(
                          width:
                              _cellsLocked[index]
                                  ? 2
                                  : 1, // Thicker border for locked cells
                          color:
                              _cellsLocked[index]
                                  ? _currentCellColors[index]
                                  : Theme.of(context).colorScheme.outline,
                        ),
                        color: _currentCellColors[index],
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: [
                          BoxShadow(
                            // ignore: deprecated_member_use
                            color: Colors.black.withOpacity(
                              0.3 * widget.animationController.value,
                            ),
                            blurRadius: 5 * widget.animationController.value,
                            offset: Offset(
                              0,
                              2 * widget.animationController.value,
                            ),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child:
                          widget.animationController.value < 1.0
                              ? Text(
                                _cellTextControllers[index].text,
                                style: TextStyle(
                                  color: _getContrastColor(
                                    _currentCellColors[index],
                                  ),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.none,
                                ),
                                textWidthBasis: TextWidthBasis.parent,
                              )
                              : Material(
                                type: MaterialType.transparency,
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    double fontSize = (constraints.maxWidth *
                                            0.6)
                                        .clamp(12.0, 50.0);
                                    return SizedBox(
                                      width: cellSize * 0.9,
                                      height: cellSize * 0.9,
                                      child: Center(
                                        // Center the TextField vertically and horizontally
                                        child: TextField(
                                          controller:
                                              _cellTextControllers[index],
                                          focusNode: _cellFocusNodes[index],
                                          textAlign: TextAlign.center,
                                          textDirection: TextDirection.rtl,
                                          maxLength: 1,
                                          maxLengthEnforcement:
                                              MaxLengthEnforcement.none,
                                          onChanged: (value) {
                                            if (value.isNotEmpty) {
                                              final char =
                                                  value.characters.last;
                                              _suppressListener = true;
                                              _cellTextControllers[index]
                                                  .value = TextEditingValue(
                                                text: char,
                                                selection: TextSelection(
                                                  baseOffset: 0,
                                                  extentOffset: char.length,
                                                ),
                                              );
                                              _suppressListener = false;
                                            }
                                          },
                                          enabled:
                                              !_cellsLocked[index], // Disable input for locked cells
                                          style: TextStyle(
                                            color: _getContrastColor(
                                              _currentCellColors[index],
                                            ),
                                            fontSize: fontSize,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                            counterText: "",
                                            contentPadding: EdgeInsets.all(0),
                                            isDense: true,
                                          ),
                                          cursorColor: _getContrastColor(
                                            _currentCellColors[index],
                                          ),
                                          textInputAction:
                                              (index ==
                                                      widget
                                                              .cellsToAnimate
                                                              .length -
                                                          1)
                                                  ? TextInputAction.done
                                                  : TextInputAction.next,
                                          onSubmitted: (_) {
                                            // Find next unlocked cell
                                            int nextIndex = index + 1;
                                            while (nextIndex <
                                                    _cellTextControllers
                                                        .length &&
                                                _cellsLocked[nextIndex]) {
                                              nextIndex++;
                                            }

                                            if (nextIndex <
                                                _cellTextControllers.length) {
                                              FocusScope.of(
                                                context,
                                              ).requestFocus(
                                                _cellFocusNodes[nextIndex],
                                              );
                                              _cellTextControllers[nextIndex]
                                                  .selection = TextSelection(
                                                baseOffset: 0,
                                                extentOffset:
                                                    _cellTextControllers[nextIndex]
                                                        .text
                                                        .length,
                                              );
                                            } else {
                                              _handleDismissOrSubmit();
                                            }
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                    ),
                  ),
                );
              }),
              Positioned(
                bottom: centerY + cellSize + 30,
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: widget.animationController.value,
                  child: Center(child: SizedBox.shrink()),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
