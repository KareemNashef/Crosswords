// Flutter imports
import 'package:flutter/material.dart';
import 'dart:ui'; // For ImageFilter

// Local imports
import 'package:crosswords/Logic/puzzle_models.dart';

class AnimatedPopup extends StatefulWidget {
  final List<CellModel>
  cellsToAnimate; // These are copies, modify their enteredChar/color
  final AnimationController animationController;
  final String direction;
  final String clueText; // Issue 4: Only specific clue
  final String wordSolution; // Full solution for the current word
  final Function(Map<int, String>)
  onSubmitOrDismiss; // Returns map of animIndex to char

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
  _AnimatedPopupState createState() => _AnimatedPopupState();
}

class _AnimatedPopupState extends State<AnimatedPopup> {
  late List<TextEditingController> _cellTextControllers;
  late List<FocusNode> _cellFocusNodes;
  // Store local copies of cell states for real-time updates in popup
  late List<String> _currentEnteredChars;
  late List<Color> _currentCellColors;

  @override
  void initState() {
    super.initState();

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
    _currentCellColors =
        widget.cellsToAnimate.map((c) {
          if (c.enteredChar.isEmpty) return widget.initialCellColor;
          return c.enteredChar == c.solutionChar
              ? widget.correctCellColor
              : widget.errorCellColor;
        }).toList();

    // Add listener to focus on the first editable cell when animation is done
    widget.animationController.addStatusListener(_onAnimationStatusChanged);

    // Listeners for each text controller for real-time updates and focus shift
    for (int i = 0; i < _cellTextControllers.length; i++) {
      _cellTextControllers[i].addListener(() => _onCellTextChanged(i));
    }
  }

  void _onAnimationStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      if (mounted && _cellFocusNodes.isNotEmpty) {
        // Initial focus on the first logical field according to cellsToAnimate order.
        // If cellsToAnimate[0] is for '5' (visual right), this is correct.
        int focusIdx = _currentEnteredChars.indexWhere((char) => char.isEmpty);
        if (focusIdx == -1) {
          // All full
          focusIdx = 0; // Focus the first one (e.g., for '5')
        }

        if (focusIdx >= 0 && focusIdx < _cellFocusNodes.length) {
          print("AnimatedPopup: Initial focus on index $focusIdx");
          FocusScope.of(context).requestFocus(_cellFocusNodes[focusIdx]);
          _cellTextControllers[focusIdx].selection = TextSelection(
            baseOffset: 0,
            extentOffset: _cellTextControllers[focusIdx].text.length,
          );
        }
      }
    }
  }

  void _onCellTextChanged(int index) {
    // index is the index in _cellTextControllers
    String newChar = _cellTextControllers[index].text;
    final bool isAppRtl =
        Localizations.localeOf(context).languageCode == 'ar'; // Get it once
    // print("_onCellTextChanged: index=$index, newChar='$newChar', direction=${widget.direction}, isRtl=$isAppRtl, cellSolution='${widget.cellsToAnimate[index].solutionChar}'");

    if (newChar.length > 1) {
      newChar = newChar.substring(newChar.length - 1);
      _cellTextControllers[index].text = newChar;
      _cellTextControllers[index].selection = TextSelection.fromPosition(
        TextPosition(offset: newChar.length),
      );
    }

    bool isCorrectEntry = false;
    setState(() {
      _currentEnteredChars[index] = newChar;
      if (newChar.isEmpty) {
        _currentCellColors[index] = widget.initialCellColor;
      } else {
        if (newChar == widget.cellsToAnimate[index].solutionChar) {
          _currentCellColors[index] =
              widget.correctCellColor; // ensure correct variable name
          isCorrectEntry = true;
        } else {
          _currentCellColors[index] =
              widget.errorCellColor; // ensure correct variable name
        }
      }
    });

    // Auto-advance focus only if the entry is correct.
    // Advancement is always to the next logical character's text field (index + 1).
    // This corresponds to moving visually left for RTL horizontal if targetX is LTR-like.
    if (newChar.isNotEmpty && isCorrectEntry) {
      if (index < _cellTextControllers.length - 1) {
        // print("  Advancing focus from $index to ${index + 1}");
        FocusScope.of(context).requestFocus(_cellFocusNodes[index + 1]);
        _cellTextControllers[index + 1].selection = TextSelection(
          baseOffset: 0,
          extentOffset: _cellTextControllers[index + 1].text.length,
        );
      } else {
        // print("  At last field (visually leftmost for RTL horizontal), index=$index");
        // Optionally call _handleDismissOrSubmit() here if desired
      }
    }
  }

  @override
  void dispose() {
    widget.animationController.removeStatusListener(_onAnimationStatusChanged);
    for (var controller in _cellTextControllers) {
      controller.dispose();
    }
    for (var focusNode in _cellFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  Color _getContrastColor(Color backgroundColor) {
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  void _handleDismissOrSubmit() {
    Map<int, String> result = {};
    for (int i = 0; i < widget.cellsToAnimate.length; i++) {
      // Use animationIndex of the original CellModel as key
      result[widget.cellsToAnimate[i].animationIndex] = _currentEnteredChars[i];
    }
    widget.onSubmitOrDismiss(result);
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double centerX = screenSize.width / 2;
    final double centerY = screenSize.height / 2;

    // CRASH GUARD: Ensure cellSize is valid
    final double potentialCellSize =
        widget.cellsToAnimate.isNotEmpty
            ? widget.cellsToAnimate.first.originalRect.width
            : 0.0; // Default to 0 if no cells or rect not ready

    if (widget.cellsToAnimate.isEmpty || potentialCellSize <= 1.0) {
      // Use 1.0 as a minimum practical size
      // Fallback if cells are not ready or too small, prevents crash
      // You might want to show a loading indicator or an error message
      // For now, just dismiss and let the parent handle it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _handleDismissOrSubmit(); // Attempt to gracefully close
        }
      });
      return const SizedBox.shrink(); // Render nothing, will be dismissed
    }
    final double cellSize =
        potentialCellSize; // Now cellSize is guaranteed > 1.0

    final double cellSpacing = 4.0;
    final bool isRtl = Localizations.localeOf(context).languageCode == 'ar';

    final Animation<double> blurAnimation = Tween<double>(
      begin: 0.0,
      end: 5.0, // Reduced blur slightly
    ).animate(
      CurvedAnimation(
        parent: widget.animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    return WillPopScope(
      onWillPop: () async {
        _handleDismissOrSubmit();
        return true; // Allow back button to pop
      },
      child: AnimatedBuilder(
        animation: widget.animationController,
        builder: (context, child) {
          final totalAnimatedCellsWidth =
              widget.cellsToAnimate.length * (cellSize + cellSpacing) -
              cellSpacing;
          final startX = centerX - totalAnimatedCellsWidth / 2;

          // Position clue text above the cells
          final double clueTextTop =
              centerY - cellSize - 80; // Adjust as needed

          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: _handleDismissOrSubmit, // Dismiss on tap outside
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: blurAnimation.value,
                      sigmaY: blurAnimation.value,
                    ),
                    child: Container(
                      color: Colors.black.withOpacity(
                        0.4 * widget.animationController.value,
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
                    color: Colors.transparent,
                    child: Text(
                      widget
                          .clueText, // Issue 4: Display only the specific clue
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
                  ),
                ),
              ),
              ...List.generate(widget.cellsToAnimate.length, (index) {
                final cellData = widget.cellsToAnimate[index];
                final originalRect = cellData.originalRect;
                final int visualIndex =
                    cellData
                        .animationIndex; // This is 0 for first logical char, 1 for second, etc.

                double targetX;
                if (widget.direction == "horizontal") {
                  // This makes popup "5 4 3 2 1" (RTL) if cellsToAnimate[0] is '5', etc.
                  targetX =
                      startX +
                      ((widget.cellsToAnimate.length - 1 - visualIndex) *
                          (cellSize + cellSpacing));
                  //  targetX = startX + (visualIndex * (cellSize + cellSpacing));
                } else {
                  // Vertical
                  // Topmost (e.g. 'A', animIndex 0) to the right. Bottommost (e.g. 'C', animIndex 2) to the left.
                  // This displays "A B C" (RTL for vertical)
                  targetX =
                      startX +
                      ((widget.cellsToAnimate.length - 1 - visualIndex) *
                          (cellSize + cellSpacing));
                }
                final targetPosition = Offset(
                  targetX,
                  centerY - (cellSize / 2) + 10,
                ); // Adjusted padding

                final currentPosition =
                    Offset.lerp(
                      Offset(originalRect.left, originalRect.top),
                      targetPosition,
                      widget.animationController.value,
                    )!;

                final scale =
                    1.0 +
                    (0.1 *
                        widget
                            .animationController
                            .value); // Reduced scale effect

                // ... inside the AnimatedBuilder, inside the List.generate for cellsToAnimate ...
                return Positioned(
                  left: currentPosition.dx,
                  top: currentPosition.dy,
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      // This is the colored cell background
                      width: originalRect.width,
                      height: originalRect.height,
                      decoration: BoxDecoration(
                        color: _currentCellColors[index],
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: [
                          BoxShadow(
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
                                (visualIndex + 1).toString(),
                                style: TextStyle(
                                  color: _getContrastColor(
                                    _currentCellColors[index],
                                  ),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                              : Material(
                                // <<<<<<<<<< WRAP HERE
                                type:
                                    MaterialType
                                        .transparency, // To keep existing background color
                                child: SizedBox(
                                  width:
                                      cellSize *
                                      0.9, // Make it slightly smaller than cell for visual fit
                                  height: cellSize * 0.9,
                                  child: TextField(
                                    controller: _cellTextControllers[index],
                                    focusNode: _cellFocusNodes[index],
                                    textAlign: TextAlign.center,
                                    textDirection: TextDirection.rtl,
                                    maxLength: 1,
                                    style: TextStyle(
                                      color: _getContrastColor(
                                        _currentCellColors[index],
                                      ),
                                      fontSize: (cellSize * 0.6).clamp(
                                        12.0,
                                        22.0,
                                      ),
                                      fontWeight: FontWeight.bold,
                                    ),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      counterText: "",
                                      contentPadding: EdgeInsets.all(
                                        0,
                                      ), // Ensure padding is zero or minimal (e.g., EdgeInsets.symmetric(vertical: 2))
                                      isDense:
                                          true, // Reduces intrinsic padding
                                    ),
                                    cursorColor: _getContrastColor(
                                      _currentCellColors[index],
                                    ),
                                    textInputAction:
                                        (index ==
                                                widget.cellsToAnimate.length -
                                                    1)
                                            ? TextInputAction.done
                                            : TextInputAction.next,
                                    // ... inside TextField ...
                                    onSubmitted: (_) {
                                      // "Next" action on keyboard always tries to move to the next logical field.
                                      // This corresponds to moving visually left for RTL horizontal.
                                      if (index <
                                          _cellTextControllers.length - 1) {
                                        FocusScope.of(context).requestFocus(
                                          _cellFocusNodes[index + 1],
                                        );
                                        _cellTextControllers[index + 1]
                                            .selection = TextSelection(
                                          baseOffset: 0,
                                          extentOffset:
                                              _cellTextControllers[index + 1]
                                                  .text
                                                  .length,
                                        );
                                      } else {
                                        // At the last logical field (visually leftmost for RTL horizontal)
                                        _handleDismissOrSubmit();
                                      }
                                    },
                                  ),
                                ),
                              ), // END Material WRAP >>>>>>>>>>
                    ),
                  ),
                );
              }),
              // Optional: A single "Done" button if preferred over auto-dismiss or last field submit
              Positioned(
                bottom: centerY + cellSize + 30, // Adjust as needed
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: widget.animationController.value,
                  child: Center(
                    child: SizedBox.shrink(),
                    // ElevatedButton(
                    //   onPressed: _handleDismissOrSubmit,
                    //   child: const Text("تم", style: TextStyle(fontSize: 16)),
                    // ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
