// lib/widgets/active_group_colors.dart
import 'package:crosswords/Settings/group.dart';
import 'package:flutter/material.dart';

class ActiveGroupColors extends StatelessWidget {
  // Input: Map where keys are usernames and values are HEX color strings
  final Map<String, String> groupUsersColors;

  const ActiveGroupColors({
    super.key,
    required this.groupUsersColors,
  });

  @override
  Widget build(BuildContext context) {
    // Filter out entries with empty usernames or colors, just in case
    final validEntries = groupUsersColors.entries
        .where((entry) => entry.key.isNotEmpty && entry.value.isNotEmpty)
        .toList();

    if (validEntries.isEmpty) {
      // Don't show anything if there are no valid user colors to display
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Use a Wrap widget to allow items to flow onto the next line if needed
          Wrap(
            spacing: 12.0, // Horizontal spacing between chips
            runSpacing: 8.0, // Vertical spacing between lines
            alignment: WrapAlignment.start, // Align items to the start (right in RTL)
            children: validEntries.map((entry) {
              final String userName = entry.key;
              final String hexColor = entry.value;
              Color displayColor = Colors.grey; // Default fallback
              try {
                displayColor = hexStringToColor(hexColor);
              } catch (e) {
                print("Error parsing color $hexColor for $userName: $e");
              }

              // Use a Chip for a compact display
              return Chip(
                // Avatar shows the user's color
                avatar: CircleAvatar(
                  backgroundColor: displayColor,
                  radius: 10, // Smaller radius for avatar
                ),
                // Label shows the username
                label: Text(
                  userName,
                  style: TextStyle(
                    fontSize: 12,
                    // Choose label color based on chip background for contrast
                    color: getContrastColor(Theme.of(context).chipTheme.backgroundColor ?? Theme.of(context).colorScheme.surfaceVariant),
                  ),
                ),
                // Optional: Style the chip itself
                backgroundColor: Theme.of(context).chipTheme.backgroundColor ?? Theme.of(context).colorScheme.surfaceVariant,
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                visualDensity: VisualDensity.compact, // Make chip smaller
                side: BorderSide.none, // Remove default border if desired
              );
            }).toList(),
          ),
        ],
      ),
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