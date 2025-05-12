// Flutter imports
import 'dart:convert';
import 'package:crosswords/Settings/group.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Local imports
import 'package:crosswords/Logic/game_grid.dart';
import 'package:crosswords/Settings/themes.dart';
import 'package:crosswords/Settings/group.dart';

// ========== Main Page ========== //

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  MainPageState createState() => MainPageState();
}

class MainPageState extends State<MainPage> with TickerProviderStateMixin {
  // ===== Class widgets ===== //

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

    return FutureBuilder<List<String>>(
      future: _loadPuzzleNumbers(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        final puzzles = snapshot.data!;
        return GridView.count(
          crossAxisCount: 3,
          shrinkWrap: false,
          physics: ScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1,
          children: puzzles.map((p) => puzzleBar(context, p)).toList(),
        );
      },
    );
  }

  // Load puzzle numbers
  Future<List<String>> _loadPuzzleNumbers() async {
    final manifest = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap = json.decode(manifest);
    final puzzleFiles =
        manifestMap.keys
            .where(
              (path) =>
                  path.startsWith('assets/Puzzles/puzzle_') &&
                  path.endsWith('_clues.json'),
            )
            .toList();

    return puzzleFiles.map((path) => path.split('_')[1]).toList();
  }

  // Check if there is saved progress
  Future<String?> _getPuzzleProgress(String puzzleNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final savedProgress = prefs.getString('puzzle_progress_$puzzleNumber');
    if (savedProgress != null) {
      final progressMap = jsonDecode(savedProgress);
      return progressMap['progress']; // Access the "progress" entry
    }
    return null;
  }

  // ===== Build method ===== //

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Set the height
        toolbarHeight: 120,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
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
                Icons.format_paint,
                color: Theme.of(context).colorScheme.primary,
                size: 32,
              ),
            ),

            // Title
            Text(
              "كلمات متقاطعة",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),

            // Profile button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(12),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GroupSettingsPage(),
                  ),
                );
              },
              child: Icon(
                Icons.person,
                color: Theme.of(context).colorScheme.primary,
                size: 32,
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
