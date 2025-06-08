// lib/Farkle/farkle.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'dart:ui';
import 'package:crosswords/Settings/firebase_service.dart';

class FarklePage extends StatefulWidget {
  @override
  _FarklePageState createState() => _FarklePageState();
}

class _FarklePageState extends State<FarklePage> with TickerProviderStateMixin {
  // Game State
  List<int> diceValues = List.generate(6, (_) => 1);
  List<bool> diceSelected = List.generate(6, (_) => false);
  List<bool> diceKept = List.generate(6, (_) => false);
  bool gameStarted = false;
  bool isRolling = false;
  bool hasJoinedGame = false;
  bool isMyTurn = false;
  int currentTurnScore = 0;
  String? currentPlayer;
  Map<String, int> playerScores = {};
  String? localUsername;
  bool hasRolledThisAction = false;
  List<String> resetVotes = [];

  // **NEW**: State for live score preview
  int selectedDiceScore = 0;

  // Animation
  late AnimationController _rollController;
  late AnimationController _turnIndicatorController;

  // Services & Utils
  late SharedPreferences prefs;
  String? groupName;
  Random random = Random();
  late final FirebaseService _firebaseService;

  @override
  void initState() {
    super.initState();
    _firebaseService = FirebaseService();
    _initialize();
    _rollController = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this);
    _turnIndicatorController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
  }

  Future<void> _initialize() async {
    prefs = await SharedPreferences.getInstance();
    groupName = prefs.getString('groupName');
    localUsername = prefs.getString('userName');
    setState(() {});
  }

  @override
  void dispose() {
    _rollController.dispose();
    _turnIndicatorController.dispose();
    super.dispose();
  }

  void joinGame() async {
    if (groupName != null) {
      bool joined = await _firebaseService.joinFarkleGame(groupName!);
      if (joined) {
        setState(() => hasJoinedGame = true);
        _listenToGameState();
      }
    }
  }

  void _listenToGameState() {
    _firebaseService.listenToFarkleGameWithCallback(groupName!, (gameData) {
      if (!mounted) return;
      final newIsMyTurn = (gameData['currentPlayer'] == localUsername);
      setState(() {
        playerScores = Map<String, int>.from(gameData['playerScores'] ?? {});
        currentPlayer = gameData['currentPlayer'];
        gameStarted = gameData['gameStarted'] ?? false;
        resetVotes = List<String>.from(gameData['resetVotes'] ?? []);
        if (!newIsMyTurn && gameData.containsKey('turnState')) {
          final turnState = Map<String, dynamic>.from(gameData['turnState']);
          diceValues = List<int>.from(turnState['diceValues'] ?? List.generate(6, (_) => 1));
          diceKept = List<bool>.from(turnState['diceKept'] ?? List.generate(6, (_) => false));
          currentTurnScore = turnState['currentTurnScore'] ?? 0;
        }
        if (newIsMyTurn && !isMyTurn) {
          _turnIndicatorController.forward(from: 0);
          resetDiceForNewTurn();
        }
        isMyTurn = newIsMyTurn;
      });
    });
  }
  
  Future<void> _broadcastTurnState() async {
    if (groupName == null || !isMyTurn) return;
    final Map<String, dynamic> turnState = {
      'diceValues': diceValues,
      'diceKept': diceKept,
      'currentTurnScore': currentTurnScore,
    };
    await _firebaseService.updateFarkleTurnState(groupName!, turnState);
  }

  void startGame() async {
    if (isMyTurn && groupName != null) {
      await _firebaseService.startFarkleGame(groupName!);
      resetDiceForNewTurn();
      rollDice();
    }
  }

  void resetDiceForNewTurn() {
    setState(() {
      diceValues = List.generate(6, (_) => 1);
      diceSelected = List.generate(6, (_) => false);
      diceKept = List.generate(6, (_) => false);
      currentTurnScore = 0;
      selectedDiceScore = 0;
      hasRolledThisAction = false;
    });
  }

  void rollDice() {
    if (!isMyTurn || isRolling) return;
    setState(() {
      isRolling = true;
      diceSelected = List.generate(6, (_) => false);
      selectedDiceScore = 0;
    });
    _rollController.forward(from: 0.0).then((_) {
      setState(() {
        for (int i = 0; i < 6; i++) {
          if (!diceKept[i]) diceValues[i] = random.nextInt(6) + 1;
        }
        isRolling = false;
        hasRolledThisAction = true;
      });
      if (!_hasScoringDiceOnTable()) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('!فاركل! لا يوجد اختيارات ممكنة')));
        endTurn(farkled: true);
      }
      _broadcastTurnState();
    });
  }

  void toggleDiceSelection(int index) {
    if (!diceKept[index] && !isRolling && isMyTurn) {
      setState(() {
        diceSelected[index] = !diceSelected[index];
        _updateSelectedDiceScore(); // Recalculate score on every selection change
      });
    }
  }

  /// **NEW**: Recalculates the score of the currently selected (but not yet kept) dice.
  void _updateSelectedDiceScore() {
    List<int> currentlySelectedDice = [];
    for (int i = 0; i < diceSelected.length; i++) {
      if (diceSelected[i]) {
        currentlySelectedDice.add(diceValues[i]);
      }
    }
    setState(() {
      selectedDiceScore = calculateScore(currentlySelectedDice);
    });
  }

  void keepSelectedDice() {
    if (!isMyTurn || selectedDiceScore == 0) return; // Can't keep a non-scoring selection

    setState(() {
      currentTurnScore += selectedDiceScore;
      for (int i = 0; i < 6; i++) {
        if (diceSelected[i]) {
          diceKept[i] = true;
        }
      }
      diceSelected = List.generate(6, (_) => false);
      selectedDiceScore = 0;
      hasRolledThisAction = false;
      if (diceKept.every((kept) => kept)) {
          diceKept = List.generate(6, (_) => false);
      }
    });
    _broadcastTurnState();
  }

  void endTurn({bool farkled = false}) async {
    if (!isMyTurn || groupName == null) return;
    
    if(!farkled){
      await _firebaseService.updatePlayerScore(groupName!, currentTurnScore);
    }
    
    await _firebaseService.endPlayerTurn(groupName!);
    resetDiceForNewTurn();
  }

  int calculateScore(List<int> dice) {
    int score = 0;
    Map<int, int> counts = {};
    for (int die in dice) { counts[die] = (counts[die] ?? 0) + 1; }
    if (dice.length == 6 && counts.values.where((c) => c == 2).length == 3) return 1500;
    if (dice.length == 6 && counts.length == 6) return 1500;
    counts.forEach((face, count) {
      if (count >= 3) {
        score += (face == 1 ? 1000 : face * 100) * (1 << (count - 3));
        counts[face] = 0;
      }
    });
    score += (counts[1] ?? 0) * 100;
    score += (counts[5] ?? 0) * 50;
    return score;
  }
  
  bool _hasScoringDiceOnTable() {
    List<int> availableDice = [];
    for(int i = 0; i < 6; i++) {
      if (!diceKept[i]) {
        availableDice.add(diceValues[i]);
      }
    }
    if (availableDice.any((d) => d == 1 || d == 5)) return true;
    Map<int, int> counts = {};
    for(int die in availableDice) {
      counts[die] = (counts[die] ?? 0) + 1;
    }
    if (counts.values.any((c) => c >= 3)) return true;
    if (availableDice.length == 6) {
      if (counts.length == 6) return true;
      if (counts.values.where((c) => c == 2).length == 3) return true;
    }
    return false;
  }
  
  // --- UI BUILDER METHODS ---

  @override
  Widget build(BuildContext context) {
    return Container(
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
        appBar: _buildAppBar(),
        body: SafeArea(
          child: Column(
            children: [
              _buildPlayerInfo(),
              Expanded(
                child: Center(
                  child: hasJoinedGame
                      ? (gameStarted ? _buildGameArea() : _buildWaitingPrompt())
                      : _buildJoinGamePrompt(),
                ),
              ),
              if (hasJoinedGame && isMyTurn && !gameStarted) _buildStartButton(),
            ],
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).pop(),
        color: Theme.of(context).colorScheme.primary,
      ),
      centerTitle: true,
      title: Text('لعبة فاركل', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildGlassCard({required Widget child, EdgeInsets? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withOpacity(0.4),
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: child,
        ),
      ),
    );
  }
  
  Widget _buildPlayerInfo() {
    if (!hasJoinedGame || playerScores.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          _buildGlassCard(
            child: Column(
              children: [
                Text('اللاعبون', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 8),
                ...playerScores.entries.map((entry) => _PlayerScoreRow(
                  name: entry.key,
                  score: entry.value,
                  isCurrent: currentPlayer == entry.key,
                  isMe: localUsername == entry.key,
                )).toList(),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildGlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('نقاط الدور الحالي: ', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                Text('$currentTurnScore', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Theme.of(context).colorScheme.onSurface)),
                // **NEW**: Live score preview for selected dice
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  child: (selectedDiceScore > 0 && isMyTurn)
                      ? Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Text(
                            '(+${selectedDiceScore})',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.primary),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameArea() {
    // **MODIFIED**: Keep button is now enabled based on the live selectedDiceScore.
    final bool canKeep = selectedDiceScore > 0;
    final bool canRoll = !hasRolledThisAction || diceKept.every((k) => !k);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: _buildGlassCard(
            padding: const EdgeInsets.all(24),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: List.generate(6, (i) => _DiceWidget(
                value: diceValues[i],
                isSelected: diceSelected[i],
                isKept: diceKept[i],
                isRolling: isRolling,
                animation: _rollController,
                onTap: isMyTurn && hasRolledThisAction ? () => toggleDiceSelection(i) : null,
              )),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildGlassCard(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _GameButton(label: 'احتفاظ', onPressed: canKeep && !isRolling && isMyTurn ? keepSelectedDice : null),
                    _GameButton(label: 'رمي النرد', onPressed: canRoll && !isRolling && isMyTurn ? rollDice : null, isPrimary: true),
                    _GameButton(label: 'إنهاء الدور', onPressed: isMyTurn && !isRolling ? endTurn : null),
                  ],
                ),
                const SizedBox(height: 16),
                _buildResetButton(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResetButton() {
    final bool haveIVoted = resetVotes.contains(localUsername);
    final String voteText = 'تصويت لإعادة الضبط (${resetVotes.length}/${playerScores.length})';
    return _GameButton(
      label: voteText,
      onPressed: haveIVoted ? null : () => _firebaseService.voteToResetFarkleGame(groupName!),
      isPrimary: false,
    );
  }

  Widget _buildJoinGamePrompt() {
    return _buildGlassCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('انضم إلى لعبة فاركل', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 24),
          _GameButton(label: 'انضمام', onPressed: joinGame, isPrimary: true),
        ],
      ),
    );
  }

  Widget _buildWaitingPrompt() {
    return _buildGlassCard(
      child: Text('في انتظار بدء اللعبة...', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface)),
    );
  }

  Widget _buildStartButton() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: _GameButton(label: 'ابدأ اللعبة', onPressed: startGame, isPrimary: true, isLarge: true),
    );
  }
}

// --- CUSTOM WIDGETS ---
class _GameButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isLarge;
  const _GameButton({required this.label, this.onPressed, this.isPrimary = false, this.isLarge = false});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: isPrimary ? Colors.white : Theme.of(context).colorScheme.primary,
        backgroundColor: isPrimary ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.primaryContainer.withOpacity(0.7),
        padding: EdgeInsets.symmetric(horizontal: isLarge ? 40: 20, vertical: isLarge ? 16 : 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        textStyle: TextStyle(fontSize: isLarge ? 20 : 14, fontWeight: FontWeight.bold),
        disabledForegroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.38),
        disabledBackgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.12),
      ),
      child: Text(label),
    );
  }
}

class _PlayerScoreRow extends StatelessWidget {
  final String name;
  final int score;
  final bool isCurrent;
  final bool isMe;
  const _PlayerScoreRow({required this.name, required this.score, required this.isCurrent, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurfaceColor = theme.colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: BoxDecoration(
        color: isCurrent ? theme.colorScheme.primary.withOpacity(0.25) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        boxShadow: isCurrent ? [ BoxShadow( color: theme.colorScheme.primary.withOpacity(0.5), blurRadius: 8, spreadRadius: 2) ] : [],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(name, style: TextStyle(color: onSurfaceColor, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
              if (isMe) Text(' (أنت)', style: TextStyle(color: onSurfaceColor.withOpacity(0.7), fontSize: 12)),
            ],
          ),
          Text('$score', style: TextStyle(color: onSurfaceColor, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}

class _DiceWidget extends StatelessWidget {
  final int value;
  final bool isSelected, isKept;
  final bool isRolling;
  final Animation<double> animation;
  final VoidCallback? onTap;
  const _DiceWidget({required this.value, required this.isSelected, required this.isKept, required this.isRolling, required this.animation, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    Color borderColor = isKept ? theme.secondary : (isSelected ? theme.primary : Colors.white.withOpacity(0.2));
    
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final shouldAnimate = isRolling && !isKept;
        final angle = shouldAnimate ? (animation.value * (pi * 2)) : 0;
        final displayValue = shouldAnimate ? (Random().nextInt(6) + 1) : value;
        return Transform(
          transform: Matrix4.identity() ..setEntry(3, 2, 0.001) ..rotateX(angle * 1.2) ..rotateY(angle * 1.2) ..rotateZ(angle * 1.2),
          alignment: FractionalOffset.center,
          child: GestureDetector(
            onTap: onTap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    color: isKept ? theme.secondaryContainer.withOpacity(0.5) : theme.surface.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor, width: 2.5),
                  ),
                  child: _DiceFace(value: displayValue),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DiceFace extends StatelessWidget {
  final int value;
  const _DiceFace({required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GridView.count(
        crossAxisCount: 3,
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(9, (i) => _dotVisibility[value-1][i] ? _DiceDot() : Container()),
      ),
    );
  }
}

class _DiceDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).colorScheme.onSurface),
    );
  }
}

const List<List<bool>> _dotVisibility = [
  [false, false, false, false, true, false, false, false, false],
  [true, false, false, false, false, false, false, false, true],
  [true, false, false, false, true, false, false, false, true],
  [true, false, true, false, false, false, true, false, true],
  [true, false, true, false, true, false, true, false, true],
  [true, false, true, true, false, true, true, false, true],
];