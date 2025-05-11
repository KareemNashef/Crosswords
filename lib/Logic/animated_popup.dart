// Flutter imports
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/services.dart';

// Local imports
import 'package:crosswords/Logic/cell_model.dart';

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

  // Controllers
  late List<TextEditingController> _cellTextControllers;

  // ===== Class methods ===== //

  // Initialization
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

// Animation listener - Fixed version
void _onAnimationStatusChanged(AnimationStatus status) {
  if (status == AnimationStatus.completed) {
    // Add a small delay to ensure the TextField widgets are properly built
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted && _cellFocusNodes.isNotEmpty) {
        int focusIdx = _currentEnteredChars.indexWhere((char) => char.isEmpty);
        if (focusIdx == -1) {
          focusIdx = 0;
        }

        if (focusIdx >= 0 && focusIdx < _cellFocusNodes.length) {
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
    String newChar = _cellTextControllers[index].text;
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
          _currentCellColors[index] = widget.correctCellColor;
          isCorrectEntry = true;
        } else {
          _currentCellColors[index] = widget.errorCellColor;
        }
      }
    });

    if (newChar.isNotEmpty && isCorrectEntry) {
      if (index < _cellTextControllers.length - 1) {
        FocusScope.of(context).requestFocus(_cellFocusNodes[index + 1]);
        _cellTextControllers[index + 1].selection = TextSelection(
          baseOffset: 0,
          extentOffset: _cellTextControllers[index + 1].text.length,
        );
      }
    }


  }

  // Dispose
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
      end: 5.0,
    ).animate(
      CurvedAnimation(
        parent: widget.animationController,
        curve: Curves.easeOutCubic,
      ),
    );

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

          final double clueTextTop = centerY - cellSize - 80;

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
                final targetPosition = Offset(
                  targetX,
                  centerY - (cellSize / 2) + 10,
                );

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
                                child: SizedBox(
                                  width: cellSize * 0.9,
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
                                      contentPadding: EdgeInsets.all(0),
                                      isDense: true,
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
                                    onSubmitted: (_) {
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
                                        _handleDismissOrSubmit();
                                      }
                                    },
                                  ),
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
