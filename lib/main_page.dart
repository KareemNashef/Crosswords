// Flutter imports
import 'dart:async';
import 'dart:convert';
import 'package:crosswords/Utilities/color_utils.dart';
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

enum ProgressFilter { all, notStarted, inProgress, completed }

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  MainPageState createState() => MainPageState();
}

class MainPageState extends State<MainPage> with TickerProviderStateMixin {
  // ===== Class variables =====
  late final FirebaseService _firebaseService;
  late final AnimationController _animationController;
  late final AnimationController _searchAnimationController;
  late final TextEditingController _searchController;

  // State
  List<String>? _allPuzzleNumbers;
  List<String>? _filteredPuzzleNumbers;
  Map<String, String?>? _puzzleProgress;
  bool _isLoading = true;

  // Search and filter state
  String _searchQuery = '';
  ProgressFilter _currentFilter = ProgressFilter.all;
  bool _isSearchActive = false;

  // ===== Lifecycle Methods =====

  @override
  void initState() {
    super.initState();
    _firebaseService = FirebaseService();
    _searchController = TextEditingController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _searchAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchAnimationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ===== Data Loading =====

  Future<void> _loadData() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    final numbers = await _loadPuzzleNumbers();
    numbers.sort((a, b) => int.parse(a).compareTo(int.parse(b)));

    final progressFutures = numbers.map((anum) => _getPuzzleProgress(anum));
    final progressResults = await Future.wait(progressFutures);
    final progressMap = Map.fromIterables(numbers, progressResults);

    if (mounted) {
      setState(() {
        _allPuzzleNumbers = numbers;
        _puzzleProgress = progressMap;
        _isLoading = false;
      });
      _applyFilters();
      _animationController.forward(from: 0.0);
    }
  }

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

  Future<String?> _getPuzzleProgress(String puzzleNumber) async {
    final prefs = await SharedPreferences.getInstance();

    final groupName = prefs.getString('groupName');
    if (groupName == null) {
      final savedProgress = prefs.getString('puzzle_progress_$puzzleNumber');
      if (savedProgress != null) {
        final progressMap = jsonDecode(savedProgress);
        return progressMap['progress'];
      }
      return null;
    }

    return _firebaseService.getPuzzleProgress(groupName, puzzleNumber);
  }

  // ===== Search and Filter Logic =====

  void _applyFilters() {
    if (_allPuzzleNumbers == null || _puzzleProgress == null) return;

    List<String> filtered = List.from(_allPuzzleNumbers!);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered =
          filtered.where((puzzleNumber) {
            return puzzleNumber.contains(_searchQuery);
          }).toList();
    }

    // Apply progress filter
    switch (_currentFilter) {
      case ProgressFilter.notStarted:
        filtered =
            filtered.where((puzzleNumber) {
              return _puzzleProgress![puzzleNumber] == null;
            }).toList();
        break;
      case ProgressFilter.inProgress:
        filtered =
            filtered.where((puzzleNumber) {
              return _puzzleProgress![puzzleNumber] == "In Progress";
            }).toList();
        break;
      case ProgressFilter.completed:
        filtered =
            filtered.where((puzzleNumber) {
              return _puzzleProgress![puzzleNumber] == "Done";
            }).toList();
        break;
      case ProgressFilter.all:
        break;
    }

    setState(() {
      _filteredPuzzleNumbers = filtered;
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _applyFilters();
  }

  void _toggleSearch() {
    setState(() {
      _isSearchActive = !_isSearchActive;
      if (!_isSearchActive) {
        _searchController.clear();
        _searchQuery = '';
        _applyFilters();
        _searchAnimationController.reverse();
      } else {
        _searchAnimationController.forward();
      }
    });
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'تصفية الألغاز', // "Filter Puzzles"
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                _buildFilterOption(
                  'جميع الألغاز',
                  Icons.grid_view,
                  ProgressFilter.all,
                ),
                _buildFilterOption(
                  'لم تبدأ',
                  Icons.play_circle_outline,
                  ProgressFilter.notStarted,
                ),
                _buildFilterOption(
                  'قيد التنفيذ',
                  Icons.edit_outlined,
                  ProgressFilter.inProgress,
                ),
                _buildFilterOption(
                  'مكتمل',
                  Icons.check_circle_outline,
                  ProgressFilter.completed,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  Widget _buildFilterOption(
    String title,
    IconData icon,
    ProgressFilter filter,
  ) {
    final isSelected = _currentFilter == filter;
    return ListTile(
      leading: Icon(
        icon,
        color:
            isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(
        title,
        style: TextStyle(
          color:
              isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing:
          isSelected
              ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
              : null,
      onTap: () {
        setState(() {
          _currentFilter = filter;
        });
        _applyFilters();
        Navigator.pop(context);
      },
    );
  }

  // ===== Navigation =====
  void _navigateToPuzzle(String puzzleNumber) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameGrid(puzzleNumber: puzzleNumber),
      ),
    ).then((_) => _loadData());
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Icon(
                    Icons.palette_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text('الثيم'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ThemeSettingsPage(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.casino_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text('لعبة فاركل'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => FarklePage()),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.group_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text('إعدادات المجموعة'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const GroupSettingsPage(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  // ===== Build Method =====

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: backgroundGradient(context),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              if (_isSearchActive) _buildSearchBar(),
              Expanded(
                child: _isLoading ? _buildLoadingState() : _buildPuzzleGrid(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مرحباً بك', // "Welcome"
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'كلمات متقاطعة',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          _buildHeaderButton(
            icon: Icons.search,
            onPressed: _toggleSearch,
            isActive: _isSearchActive,
          ),
          const SizedBox(width: 12),
          _buildHeaderButton(
            icon: Icons.tune,
            onPressed: _showFilterBottomSheet,
            isActive: _currentFilter != ProgressFilter.all,
          ),
          const SizedBox(width: 12),
          _buildHeaderButton(
            icon: Icons.more_vert,
            onPressed: _showMoreOptions,
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton({
    required IconData icon,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color:
            isActive
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color:
              isActive
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Theme.of(context).colorScheme.onSurface,
        ),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildSearchBar() {
    return AnimatedBuilder(
      animation: _searchAnimationController,
      builder: (context, child) {
        return Container(
          height: 60 * _searchAnimationController.value,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          child: Opacity(
            opacity: _searchAnimationController.value,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'ابحث عن لغز...',
                  prefixIcon: Icon(
                    Icons.search,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  suffixIcon:
                      _searchQuery.isNotEmpty
                          ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                          : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'جاري تحميل الألغاز...',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPuzzleGrid() {
    final puzzlesToShow = _filteredPuzzleNumbers ?? [];

    if (puzzlesToShow.isEmpty) {
      return _buildEmptyState();
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: GridView.builder(
        itemCount: puzzlesToShow.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.0,
        ),
        itemBuilder: (context, index) {
          final puzzleNumber = puzzlesToShow[index];
          final progress = _puzzleProgress![puzzleNumber];

          // Staggered animation
          final delay = (index * 0.1).clamp(0.0, 1.0);
          final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: _animationController,
              curve: Interval(delay, 1.0, curve: Curves.easeOutBack),
            ),
          );

          return AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              final animValue = animation.value.clamp(0.0, 1.0);
              return Transform.scale(
                scale: animValue,
                child: Opacity(
                  opacity: animValue,
                  child: _PuzzleCard(
                    puzzleNumber: puzzleNumber,
                    progress: progress,
                    onTap: () => _navigateToPuzzle(puzzleNumber),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceVariant.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _searchQuery.isNotEmpty
                  ? Icons.search_off
                  : Icons.filter_list_off,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'لا توجد ألغاز تطابق البحث'
                : 'لا توجد ألغاز في هذه القائمة',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _PuzzleCard extends StatefulWidget {
  final String puzzleNumber;
  final String? progress;
  final VoidCallback onTap;

  const _PuzzleCard({
    required this.puzzleNumber,
    this.progress,
    required this.onTap,
  });

  @override
  State<_PuzzleCard> createState() => _PuzzleCardState();
}

class _PuzzleCardState extends State<_PuzzleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color cardColor;
    Color textColor;
    IconData? statusIcon;
    Color? iconColor;

    switch (widget.progress) {
      case "Done":
        cardColor = theme.colorScheme.primaryContainer;
        textColor = theme.colorScheme.onPrimaryContainer;
        statusIcon = Icons.check_circle;
        iconColor = Colors.green.shade600;
        break;
      case "In Progress":
        cardColor = theme.colorScheme.tertiaryContainer;
        textColor = theme.colorScheme.onTertiaryContainer;
        statusIcon = Icons.edit_outlined;
        iconColor = Colors.orange.shade700;
        break;
      default:
        cardColor = theme.colorScheme.surface;
        textColor = theme.colorScheme.onSurface;
        statusIcon = Icons.play_circle_outline;
        iconColor = theme.colorScheme.primary;
    }

    return AnimatedBuilder(
      animation: _hoverController,
      builder: (context, child) {
        final scale = 1.0 - (_hoverController.value * 0.05);
        return Transform.scale(
          scale: _isPressed ? 0.95 : scale,
          child: GestureDetector(
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            onTap: widget.onTap,
            child: Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Main content
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (statusIcon != null)
                          Icon(statusIcon, color: iconColor, size: 24),
                        const SizedBox(height: 8),
                        Text(
                          'لغز',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: textColor.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.puzzleNumber,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Ripple effect overlay
                  Positioned.fill(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: widget.onTap,
                        splashColor: textColor.withValues(alpha: 0.1),
                        highlightColor: textColor.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
