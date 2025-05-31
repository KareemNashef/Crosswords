// Flutter imports
import 'package:flutter/material.dart';

// Local imports
import 'package:crosswords/Utilities/color_utils.dart';

// ========== Active Group Data ========== //

class ActiveGroupData extends StatefulWidget {
  // ===== Class variables ===== //

  final Map<String, String> groupUsersColors;
  final Map<String, int> groupUsersScores;
  final Map<String, bool> groupUsersActive;


  // Constructor
  const ActiveGroupData({
    super.key,
    required this.groupUsersColors,
    required this.groupUsersScores,
    required this.groupUsersActive,
  });

  @override
  State<ActiveGroupData> createState() => ActiveGroupDataState();
}

class ActiveGroupDataState extends State<ActiveGroupData> {
  // ===== Build method ===== //

  @override
  Widget build(BuildContext context) {

    // Get valid entries
    final validEntries =
        widget.groupUsersColors.entries
            .where((entry) => entry.key.isNotEmpty && entry.value.isNotEmpty)
            .toList();

    if (validEntries.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12.0,
            runSpacing: 8.0,
            alignment: WrapAlignment.start,
            children:
                validEntries.map((entry) {
                  final userName = entry.key;
                  final hexColor = entry.value;
                  final displayColor = hexStringToColor(hexColor);
                  final score = widget.groupUsersScores[userName] ?? 0;

                  return Chip(
                    avatar: CircleAvatar(
                      backgroundColor: displayColor,
                      radius: 10,
                    ),
                    label: Text(
                      '$userName ($score)',
                      style: TextStyle(
                        fontSize: 12,
                        color: getContrastColor(
                          Theme.of(context).chipTheme.backgroundColor ??
                              Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ),
                    backgroundColor:
                        Theme.of(context).chipTheme.backgroundColor ??
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    visualDensity: VisualDensity.compact,
                    side: BorderSide(
                      color: widget.groupUsersActive[userName] ?? false
                          ? displayColor
                          : Colors.transparent,
                      width: 1,
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }
}
