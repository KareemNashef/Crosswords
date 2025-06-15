// Flutter imports
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

// Local imports
import 'package:crosswords/Farkle/farkle_page.dart';
import 'package:crosswords/Logic/game_grid.dart';
import 'package:crosswords/Settings/firebase_service.dart';
import 'package:crosswords/Settings/group.dart';
import 'package:crosswords/Settings/themes.dart';

// ========== Main Page ========== //

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  MainPageState createState() => MainPageState();
}

class MainPageState extends State<MainPage> with TickerProviderStateMixin {
  // ===== Class variables =====
  late final FirebaseService _firebaseService;
  late final AnimationController _animationController;

  // State
  List<String>? _puzzleNumbers;
  Map<String, String?>? _puzzleProgress;
  bool _isLoading = true;

  // ===== Lifecycle Methods =====

  @override
  void initState() {
    super.initState();
    _firebaseService = FirebaseService();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ===== Data Loading =====

  Future<void> _loadData() async {
    // Show loading indicator
    if (mounted) {
      setState(() => _isLoading = true);
    }

    final numbers = await _loadPuzzleNumbers();
    // Sort puzzles numerically instead of lexicographically
    numbers.sort((a, b) => int.parse(a).compareTo(int.parse(b)));

    // Fetch all progress data in parallel for efficiency
    final progressFutures = numbers.map((anum) => _getPuzzleProgress(anum));
    final progressResults = await Future.wait(progressFutures);

    final progressMap = Map.fromIterables(numbers, progressResults);

    if (mounted) {
      setState(() {
        _puzzleNumbers = numbers;
        _puzzleProgress = progressMap;
        _isLoading = false;
      });
      // Start the animations once the data is ready
      _animationController.forward(from: 0.0);
    }
  }

  Future<List<String>> _loadPuzzleNumbers() async {
    final manifest = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap = json.decode(manifest);
    final puzzleFiles = manifestMap.keys
        .where(
          (path) =>
              path.startsWith('assets/Puzzles/puzzle_') &&
              path.endsWith('_clues.json'),
        )
        .toList();

    return puzzleFiles.map((path) => path.split('_')[1]).toList();
  }

  Future<String?> _getPuzzleProgress(String puzzleNumber) async {
    final prefs = await SharedPreferences.getInstance();

    final groupName = prefs.getString('groupName');
    if (groupName == null) {
      // Get local progress
      final savedProgress = prefs.getString('puzzle_progress_$puzzleNumber');
      if (savedProgress != null) {
        final progressMap = jsonDecode(savedProgress);
        return progressMap['progress'];
      }
      return null;
    }

    // Otherwise get from Firebase
    return _firebaseService.getPuzzleProgress(
      groupName,
      puzzleNumber,
    );
  }

  // ===== Navigation =====
  void _navigateToPuzzle(String puzzleNumber) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameGrid(puzzleNumber: puzzleNumber),
      ),
      // When we return from a puzzle, reload data to show updated progress
    ).then((_) => _loadData());
  }

  // ===== Build Method =====

  @override
  Widget build(BuildContext context) {
    return Container(
      // A beautiful gradient background that covers the whole page
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.secondaryContainer,
            Theme.of(context).colorScheme.tertiaryContainer,
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 80,
          title: Text(
            "كلمات متقاطعة",
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 28,
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: Icon(
              Icons.palette_outlined,
              color: Theme.of(context).colorScheme.primary,
              size: 28,
            ),
            tooltip: 'Themes',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ThemeSettingsPage()),
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                Icons.casino_outlined,
                color: Theme.of(context).colorScheme.primary,
                size: 28,
              ),
              tooltip: 'Farkle Game',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FarklePage()),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.group_outlined,
                color: Theme.of(context).colorScheme.primary,
                size: 28,
              ),
              tooltip: 'Group Settings',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GroupSettingsPage()),
              ),
            ),
            const SizedBox(width: 8), // Padding
          ],
        ),
        body: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
              )
            : _buildPuzzleGrid(),
      ),
    );
  }

  Widget _buildPuzzleGrid() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
      child: GridView.builder(
        itemCount: _puzzleNumbers?.length ?? 0,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.9,
        ),
        itemBuilder: (context, index) {
          final puzzleNumber = _puzzleNumbers![index];
          final progress = _puzzleProgress![puzzleNumber];

          // Create a staggered animation for each card
          final interval = Interval(
            (0.1 * index) / (_puzzleNumbers!.length * 0.1),
            1.0,
            curve: Curves.easeOutCubic,
          );
          final animation = _animationController
              .drive(Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: interval)));

          return AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              return Transform.scale(
                scale: animation.value,
                child: Opacity(
                  opacity: animation.value,
                  child: child,
                ),
              );
            },
            child: _PuzzleCard(
              puzzleNumber: puzzleNumber,
              progress: progress,
              onTap: () => _navigateToPuzzle(puzzleNumber),
            ),
          );
        },
      ),
    );
  }
}

// A new widget for the puzzle selection card for better code organization
class _PuzzleCard extends StatelessWidget {
  final String puzzleNumber;
  final String? progress;
  final VoidCallback onTap;

  const _PuzzleCard({
    required this.puzzleNumber,
    this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Icon? progressIcon;
    Color cardColor = theme.colorScheme.surface.withValues(alpha:0.5);

    if (progress == "Done") {
      cardColor = theme.colorScheme.primaryContainer.withValues(alpha:0.7);
      progressIcon = Icon(Icons.check_circle, color: Colors.green.shade600, size: 20);
    } else if (progress == "In Progress") {
      cardColor = theme.colorScheme.tertiaryContainer.withValues(alpha:0.7);
      progressIcon = Icon(Icons.edit, color: Colors.orange.shade800, size: 20);
    }

    return Card(
      color: cardColor,
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias, // Ensures the InkWell ripple stays within the rounded corners
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'لغز', // "Puzzle"
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    puzzleNumber,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            // Progress icon indicator
            if (progressIcon != null)
              Positioned(
                top: 8,
                right: 8,
                child: progressIcon,
              ),
          ],
        ),
      ),
    );
  }
}