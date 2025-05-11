// Flutter imports
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Local imports
import 'package:crosswords/Logic/game_grid.dart';
import 'package:crosswords/themes.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  MainPageState createState() => MainPageState();
}

class MainPageState extends State<MainPage> with TickerProviderStateMixin {
  // App color selection bar
  Widget puzzleSelectionBar(context) {
    
Widget puzzleBar(BuildContext context, String puzzleNumber) {
  return FutureBuilder<String?>(
    future: _getPuzzleProgress(puzzleNumber),
    builder: (context, snapshot) {
      final progress = snapshot.data;
      Color bgColor;
      if (progress == "Done") {
        bgColor = Theme.of(context).colorScheme.primaryContainer;
      } else if (progress == "In Progress") {
        bgColor = Theme.of(context).colorScheme.errorContainer;
      } else {
        bgColor = Theme.of(context).colorScheme.secondaryContainer;
      }

      return OutlinedButton(
        style: OutlinedButton.styleFrom(
          fixedSize: const Size(350, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: bgColor,
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GameGrid(puzzleNumber: puzzleNumber),
            ),
          ).then((_) => setState(() {}));
        },
        child: Text(puzzleNumber),
      );
    },
  );
}


    return Column(
      children: [
        puzzleBar(context, "4404"),
        SizedBox(height: 16),
        puzzleBar(context, "4410"),
        SizedBox(height: 16),
        puzzleBar(context, "4416"),
        SizedBox(height: 16),
        puzzleBar(context, "4422"),
        SizedBox(height: 16),
        puzzleBar(context, "4426"),
        SizedBox(height: 16),
        puzzleBar(context, "4433"),
        SizedBox(height: 16),
        puzzleBar(context, "4440"),
        SizedBox(height: 16),
        puzzleBar(context, "4444"),
        SizedBox(height: 16),
        puzzleBar(context, "4448"),
        SizedBox(height: 16),
        puzzleBar(context, "4455"),
        SizedBox(height: 16),
      ],
    );
  }

  // Check if there is saved progress
Future<String?> _getPuzzleProgress(String puzzleNumber) async {
  final prefs = await SharedPreferences.getInstance();
  final savedProgress = prefs.getString('puzzle_progress_$puzzleNumber');
  if (savedProgress != null) {
    final progressMap = jsonDecode(savedProgress);
    return progressMap['progress'];  // Access the "progress" entry
  }
  return null;
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Set the height
        toolbarHeight: 120,
        title: Row(
          children: [
            // Settings button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(12),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ThemeSettingsPage(),
                  ),
                );
              },
              child: Icon(
                Icons.settings,
                color: Theme.of(context).colorScheme.primary,
                size: 32,
              ),
            ),
            SizedBox(width: 44),
            // Title
            Text(
              "كلمات متقاطعة",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Center(child: puzzleSelectionBar(context)),
    );
  }
}
