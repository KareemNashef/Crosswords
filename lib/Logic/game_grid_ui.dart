// lib/Logic/game_grid_ui.dart

import 'dart:ui';
import 'package:flutter/material.dart';

// Local imports
import 'package:crosswords/Logic/active_group_data.dart';
import 'package:crosswords/Logic/cell_model.dart';
import 'package:crosswords/Utilities/color_utils.dart';

/// A stateless widget responsible for building the UI of the game grid screen.
/// It receives all necessary data and callbacks from the parent GameGrid widget.
class GameGridUI extends StatelessWidget {
  final int gridSize;
  final bool isLoading;
  final bool isPuzzleSolved;
  final bool isInGroup;
  final List<List<CellModel>> gridCellData;
  final List<List<GlobalKey>> gridKeys;
  final Map<String, String> userColors;
  final Map<String, int> userScores;
  final Map<String, bool> userActive;
  final void Function(DragStartDetails, int, int) onPanStart;
  final void Function(DragUpdateDetails) onPanUpdate;
  final void Function(DragEndDetails) onPanEnd;
  final VoidCallback onBackToMenu;

  const GameGridUI({
    super.key,
    required this.gridSize,
    required this.isLoading,
    required this.isPuzzleSolved,
    required this.isInGroup,
    required this.gridCellData,
    required this.gridKeys,
    required this.userColors,
    required this.userScores,
    required this.userActive,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.onBackToMenu,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }

    const double rowHeaderWidth = 24.0;
    const double gridMargin = 8.0;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(gridMargin),
          child: Column(
            children: [
              // --- Column Headers Row ---
              Row(
                children: <Widget>[
                  SizedBox(
                    width: rowHeaderWidth + gridMargin,
                  ), // Offset for empty corner
                  Expanded(child: _buildColumnHeaders(context)),
                ],
              ),
              const SizedBox(height: 4),

              // --- Grid and Row Headers Row ---
              // IntrinsicHeight ensures the RowHeader Column stretches to the same height as the Grid
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // Row Headers
                    _buildRowHeaders(context, rowHeaderWidth),
                    const SizedBox(width: gridMargin),
                    // Grid
                    Expanded(child: _buildGrid(context)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (isInGroup) _buildGroupInfoSection(context),
              const SizedBox(height: 16),
            ],
          ),
        ),
        _buildSolvedOverlay(context),
      ],
    );
  }

  Widget _buildColumnHeaders(BuildContext context) {
    return Row(
      children: List.generate(gridSize, (index) {
        final headerNum = index + 1;

        // Using Expanded with flex: 1 makes each header take up equal space,
        // perfectly aligning them with the grid columns.
        return Expanded(
          flex: 1,
          child: Center(
            child: Text(
              '$headerNum',
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

  Widget _buildRowHeaders(BuildContext context, double headerWidth) {
    return SizedBox(
      width: headerWidth,
      child: Column(
        children: List.generate(gridSize, (index) {
          final headerNum = index + 1;

          // Using Expanded with flex: 1 makes each header take up equal space vertically,
          // perfectly aligning them with the grid rows.
          return Expanded(
            flex: 1,
            child: Center(
              child: Text(
                '$headerNum',
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

  Widget _buildGrid(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4), // Sharper corners
          color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: GridView.builder(
          padding: const EdgeInsets.all(2),
          physics: const NeverScrollableScrollPhysics(),
          itemCount: gridSize * gridSize,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: gridSize,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemBuilder: (context, index) {
            final row = index ~/ gridSize;
            final col = (gridSize - 1) - (index % gridSize);
            final cell = gridCellData[row][col];
            final GlobalKey cellKey = gridKeys[row][col];

            Widget cellContent = AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: cell.isBlackSquare ? Colors.black87 : cell.displayColor,
                borderRadius: BorderRadius.circular(2),
              ),
              alignment: Alignment.center,
              child:
                  cell.isBlackSquare
                      ? null
                      : LayoutBuilder(
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

            return GestureDetector(
              key: cellKey,
              onPanStart: (details) => onPanStart(details, row, col),
              onPanUpdate: onPanUpdate,
              onPanEnd: onPanEnd,
              child: cellContent,
            );
          },
        ),
      ),
    );
  }

  Widget _buildGroupInfoSection(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: Theme.of(context).cardColor.withOpacity(0.5),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "إحصائيات المجموعة",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            ActiveGroupData(
              groupUsersColors: userColors,
              groupUsersScores: userScores,
              groupUsersActive: userActive,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSolvedOverlay(BuildContext context) {
    return IgnorePointer(
      ignoring: !isPuzzleSolved,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        opacity: isPuzzleSolved ? 1.0 : 0.0,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            color: Colors.black.withOpacity(0.3),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.star_rounded,
                    color: Colors.amber,
                    size: 100,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "لقد أكملت المستوى بنجاح!",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.menu_book),
                    label: const Text("الرجوع إلى القائمة"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: onBackToMenu,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
