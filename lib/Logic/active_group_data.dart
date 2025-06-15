// lib/Logic/active_group_data.dart

// Flutter imports
import 'dart:ui';
import 'package:flutter/material.dart';

// Local imports
import 'package:crosswords/Utilities/color_utils.dart';

// ========== Active Group Data ========== //

class ActiveGroupData extends StatefulWidget {
  final Map<String, String> groupUsersColors;
  final Map<String, int> groupUsersScores;
  final Map<String, bool> groupUsersActive;

  const ActiveGroupData({
    super.key,
    required this.groupUsersColors,
    required this.groupUsersScores,
    required this.groupUsersActive,
  });

  @override
  State<ActiveGroupData> createState() => ActiveGroupDataState();
}

class ActiveGroupDataState extends State<ActiveGroupData>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get valid entries and sort them by score (descending)
    final sortedEntries =
        widget.groupUsersColors.entries
            .where((entry) => entry.key.isNotEmpty && entry.value.isNotEmpty)
            .toList()
          ..sort((a, b) {
            final scoreA = widget.groupUsersScores[a.key] ?? 0;
            final scoreB = widget.groupUsersScores[b.key] ?? 0;
            return scoreB.compareTo(scoreA); // Sort descending
          });

    if (sortedEntries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 12.0,
      runSpacing: 12.0,
      alignment:
          WrapAlignment.center, // Center the cards within the available space
      children:
          sortedEntries.map((entry) {
            final userName = entry.key;
            final hexColor = entry.value;
            final displayColor = hexStringToColor(hexColor);
            final score = widget.groupUsersScores[userName] ?? 0;
            final isActive = widget.groupUsersActive[userName] ?? false;

            return _UserStatusCard(
              userName: userName,
              score: score,
              color: displayColor,
              isActive: isActive,
              animation: _animationController,
            );
          }).toList(),
    );
  }
}

/// A "glassmorphism" card widget to display a single user's status.
class _UserStatusCard extends StatelessWidget {
  final String userName;
  final int score;
  final Color color;
  final bool isActive;
  final Animation<double> animation;

  const _UserStatusCard({
    required this.userName,
    required this.score,
    required this.color,
    required this.isActive,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = theme.cardColor.withValues(alpha:0.4);
    final onCardColor = getContrastColor(cardColor);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          height: 60,
          padding: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: Colors.white.withValues(alpha:0.1)),
          ),
          child: Row(
            mainAxisSize:
                MainAxisSize.min, // Make the row take up minimum space
            children: [
              // User's Color Bar
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 12),

              // User Name and Score
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: onCardColor,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '$score',
                    style: TextStyle(
                      color: onCardColor.withValues(alpha:0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),

              // Active Indicator
              if (isActive)
                AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    // Use a curve to make the pulse more natural
                    final easeAnimation = CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeInOut,
                    );
                    return Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.greenAccent,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.greenAccent.withValues(alpha:
                              0.7 * easeAnimation.value,
                            ),
                            blurRadius: 8.0 * easeAnimation.value,
                            spreadRadius: 2.0 * easeAnimation.value,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}
