import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

import 'package:crosswords/Settings/firebase_service.dart';
import 'logic/dice_model.dart';
import 'logic/farkle_logic.dart';
import 'widgets/dice_widget.dart';
import 'widgets/game_button.dart';
import 'widgets/glass_card.dart';
import 'widgets/player_score_row.dart';

class FarklePage extends StatefulWidget {
  const FarklePage({super.key});

  @override
  _FarklePageState createState() => _FarklePageState();
}

class _FarklePageState extends State<FarklePage> with TickerProviderStateMixin {
  // Game State
  List<BaseDice> dice = List.generate(6, (_) => StandardDice());
  List<bool> diceSelected = List.generate(6, (_) => false);
  List<bool> diceKept = List.generate(6, (_) => false);
  int currentTurnScore = 0;
  int selectedDiceScore = 0;
  bool isCurrentSelectionValid = false;
  bool hasRolled = false;

  // Multiplayer State
  bool gameStarted = false;
  bool isRolling = false;
  bool hasJoinedGame = false;
  bool isMyTurn = false;
  String? currentPlayer;
  Map<String, int> playerScores = {};
  String? localUsername;
  List<String> resetVotes = [];

  // Animation
  late AnimationController _rollController;

  // Services & Utils
  late SharedPreferences prefs;
  String? groupName;
  late final FirebaseService _firebaseService;

  @override
  void initState() {
    super.initState();
    _firebaseService = FirebaseService();
    _initialize();
    
    _rollController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (isMyTurn) {
          setState(() {
            for (int i = 0; i < 6; i++) {
              if (!diceKept[i]) {
                dice[i].roll();
              }
            }
            isRolling = false;
            hasRolled = true;
          });
          if (!_hasScoringDiceAfterRoll()) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('!فاركل! لا يوجد اختيارات ممكنة')),
            );
            endTurn(farkled: true);
          } else {
            _broadcastTurnState(rolling: false);
          }
        } else {
          setState(() => isRolling = false);
        }
      }
    });
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
      final newCurrentPlayer = gameData['currentPlayer'] as String?;
      
      if (currentPlayer != newCurrentPlayer) {
        _loadDiceForPlayer(newCurrentPlayer, gameData);
      }
      
      setState(() {
        playerScores = Map<String, int>.from(gameData['playerScores'] ?? {});
        currentPlayer = newCurrentPlayer;
        gameStarted = gameData['gameStarted'] ?? false;
        resetVotes = List<String>.from(gameData['resetVotes'] ?? []);
        
        final turnState = gameData.containsKey('turnState') ? Map<String, dynamic>.from(gameData['turnState']) : null;
        
        if (newIsMyTurn && !isMyTurn) { 
          _resetForNewTurn();
        }
        isMyTurn = newIsMyTurn;

        if (turnState != null) {
          final diceValues = List<int>.from(turnState['diceValues'] ?? List.generate(6, (_) => 1));
          for(int i = 0; i < 6; i++) { dice[i].value = diceValues[i]; }
          diceKept = List<bool>.from(turnState['diceKept'] ?? List.generate(6, (_) => false));
          currentTurnScore = turnState['currentTurnScore'] ?? 0;
          final bool remoteRolling = turnState['isRolling'] ?? false;
          if (remoteRolling && !isRolling) {
            isRolling = true;
            _rollController.forward(from: 0);
          } else if (!remoteRolling && isRolling && !isMyTurn) {
            isRolling = false;
          }
        }
      });
    });
  }

  void _loadDiceForPlayer(String? playerName, Map<String, dynamic> gameData) {
    if (playerName == null) return;
    
    final configs = Map<String, dynamic>.from(gameData['playerDiceConfigs'] ?? {});
    final playerConfig = List<String>.from(configs[playerName] ?? []);

    if (playerConfig.isNotEmpty) {
      setState(() {
        dice = playerConfig.map((typeId) => BaseDice.fromId(typeId)).toList();
      });
    } else {
      setState(() {
        dice = List.generate(6, (_) => StandardDice());
      });
    }
  }

  Future<void> _broadcastTurnState({required bool rolling}) async {
    if (groupName == null || !isMyTurn) return;
    final Map<String, dynamic> turnState = {
      'diceValues': dice.map((d) => d.value).toList(),
      'diceKept': diceKept,
      'currentTurnScore': currentTurnScore,
      'isRolling': rolling,
    };
    await _firebaseService.updateFarkleTurnState(groupName!, turnState);
  }

  void startGame() async {
    if (isMyTurn && groupName != null) {
      await _firebaseService.startFarkleGame(groupName!);
      _resetForNewTurn();
      _initialRoll();
    }
  }

  void _resetForNewTurn() {
    setState(() {
      diceSelected = List.generate(6, (_) => false);
      diceKept = List.generate(6, (_) => false);
      currentTurnScore = 0;
      selectedDiceScore = 0;
      isCurrentSelectionValid = false;
      hasRolled = false;
    });
  }

  void _rollDiceAction() {
    if (!isMyTurn || isRolling || !isCurrentSelectionValid) return;
    setState(() {
      currentTurnScore += selectedDiceScore;
      for (int i = 0; i < 6; i++) {
        if (diceSelected[i]) {
          diceKept[i] = true;
        }
      }
      diceSelected = List.generate(6, (_) => false);
      selectedDiceScore = 0;
      isCurrentSelectionValid = false;
      if (diceKept.every((kept) => kept)) {
        diceKept = List.generate(6, (_) => false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('نرد ساخن! يمكنك الرمي مرة أخرى')),);
      }
      isRolling = true;
      _broadcastTurnState(rolling: true);
      _rollController.forward(from: 0.0);
    });
  }

  void _initialRoll() {
    if (!isMyTurn || isRolling || hasRolled) return;
    setState(() {
      isRolling = true;
      _broadcastTurnState(rolling: true);
      _rollController.forward(from: 0.0);
    });
  }

  void toggleDiceSelection(int index) {
    if (diceKept[index] || isRolling || !isMyTurn || !hasRolled) return;
    setState(() {
      diceSelected[index] = !diceSelected[index];
      _updateSelectedDiceScore();
    });
  }

  void _updateSelectedDiceScore() {
    List<int> currentlySelectedValues = [];
    for (int i = 0; i < diceSelected.length; i++) {
      if (diceSelected[i]) {
        currentlySelectedValues.add(dice[i].value);
      }
    }
    setState(() {
      selectedDiceScore = calculateScore(currentlySelectedValues);
      isCurrentSelectionValid = isSelectionValid(currentlySelectedValues);
    });
  }

  void endTurn({bool farkled = false}) async {
    if (!isMyTurn || groupName == null) return;
    int finalTurnScore = currentTurnScore;
    if (!farkled) {
      if (isCurrentSelectionValid) {
        finalTurnScore += selectedDiceScore;
      }
      if (finalTurnScore > 0) {
        await _firebaseService.updatePlayerScore(groupName!, finalTurnScore);
      }
    }
    await _firebaseService.endPlayerTurn(groupName!);
    _resetForNewTurn();
  }

  bool _hasScoringDiceAfterRoll() {
    List<int> availableDice = [];
    for (int i = 0; i < 6; i++) {
      if (!diceKept[i]) {
        availableDice.add(dice[i].value);
      }
    }
    return hasScoringDiceOnTable(availableDice);
  }

  void _showDiceSelectionModal() {
    List<BaseDice> modalDice = dice.map((d) => BaseDice.fromId(d.typeId)).toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter modalSetState) {
            Widget buildDiceSwitchTile<T extends BaseDice>({
              required String title,
              required String subtitle,
              required IconData icon,
              required Color iconColor,
              required BaseDice Function() diceBuilder,
            }) {
              final hasThisDice = modalDice.any((d) => d is T);
              final hasStandardSlot = modalDice.any((d) => d is StandardDice);
              return SwitchListTile(
                title: Text(title),
                subtitle: Text(subtitle),
                value: hasThisDice,
                onChanged: (hasThisDice && !hasStandardSlot) ? null : (bool isToggledOn) {
                  modalSetState(() {
                    if (isToggledOn) {
                      final index = modalDice.indexWhere((d) => d is StandardDice);
                      if (index != -1) modalDice[index] = diceBuilder();
                    } else {
                      final index = modalDice.indexWhere((d) => d is T);
                      if (index != -1) modalDice[index] = StandardDice();
                    }
                  });
                },
                secondary: Icon(icon, color: iconColor),
                activeColor: iconColor,
              );
            }
            final standardDiceCount = modalDice.where((d) => d is StandardDice).length;
            return GlassCard(
              padding: const EdgeInsets.only(top: 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("تخصيص النرد", style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface)),
                  const SizedBox(height: 8),
                  Text("النرد العادي المتبقي: $standardDiceCount", style: Theme.of(context).textTheme.bodySmall),
                  const Divider(height: 20),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        buildDiceSwitchTile<LuckyDice>(title: "النرد المحظوظ", subtitle: "فرصة أعلى للحصول على 1 و 5", icon: Icons.star, iconColor: Colors.amber, diceBuilder: () => LuckyDice()),
                        buildDiceSwitchTile<CelestialDice>(title: "النرد السماوي", subtitle: "لا يمكن أن يظهر الأرقام 3 أو 4", icon: Icons.wb_sunny, iconColor: Colors.lightBlue.shade200, diceBuilder: () => CelestialDice()),
                        buildDiceSwitchTile<ShadowDice>(title: "نرد الظل", subtitle: "فرصة أعلى للأرقام المتوسطة (2,3,4)", icon: Icons.nightlight_round, iconColor: Colors.deepPurple.shade300, diceBuilder: () => ShadowDice()),
                        buildDiceSwitchTile<UnstableDice>(title: "النرد المتقلب", subtitle: "قد يُصلح الرميات السيئة", icon: Icons.whatshot, iconColor: Colors.red.shade400, diceBuilder: () => UnstableDice()),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: GameButton(
                      label: "حفظ",
                      isPrimary: true,
                      onPressed: () {
                        setState(() => dice = modalDice);
                        if (groupName != null) {
                          final diceTypeIds = dice.map((d) => d.typeId).toList();
                          _firebaseService.updatePlayerDiceConfig(groupName!, diceTypeIds);
                        }
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // NEW: Method to show the scoring rules dialog
  void _showRulesDialog() {
    Widget buildRuleRow(String score, String combination) {
      return ListTile(
        title: Text(combination),
        trailing: Text(score, style: const TextStyle(fontWeight: FontWeight.bold)),
      );
    }
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("قواعد التسجيل"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                buildRuleRow("100", "نرد واحد بقيمة 1"),
                buildRuleRow("50", "نرد واحد بقيمة 5"),
                buildRuleRow("300", "ثلاثة من 2"),
                buildRuleRow("400", "ثلاثة من 4"),
                buildRuleRow("500", "ثلاثة من 5"),
                buildRuleRow("600", "ثلاثة من 6"),
                buildRuleRow("1000", "ثلاثة من 1"),
                const Divider(),
                buildRuleRow("500", "ستريت (1-2-3-4-5)"),
                buildRuleRow("750", "ستريت (2-3-4-5-6)"),
                buildRuleRow("1500", "ستريت كبير (1-2-3-4-5-6)"),
                buildRuleRow("1500", "ثلاثة أزواج"),
                const Divider(),
                const ListTile(
                  title: Text("4، 5، أو 6 من نفس النوع"),
                  subtitle: Text("تتضاعف نقاط الثلاثة من نفس النوع لكل نرد إضافي."),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("حسناً"),
            )
          ],
        );
      },
    );
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
                child: Center( // Center the prompts
                  child: hasJoinedGame
                      ? (gameStarted ? _buildGameArea() : _buildWaitingPrompt())
                      : _buildJoinGamePrompt(),
                ),
              ),
              if (hasJoinedGame && gameStarted) _buildControlsArea(),
              if (hasJoinedGame && isMyTurn && !gameStarted)
                _buildStartButton(),
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
      // NEW: Add the info button to the AppBar
      actions: [
        IconButton(
          icon: const Icon(Icons.info_outline),
          color: Theme.of(context).colorScheme.primary,
          onPressed: _showRulesDialog,
          tooltip: 'قواعد اللعبة',
        ),
      ],
    );
  }

  Widget _buildPlayerInfo() {
    if (!hasJoinedGame || playerScores.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          GlassCard(
            child: Column(
              children: [
                Text('اللاعبون', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 8),
                ...playerScores.entries.map((entry) => PlayerScoreRow(name: entry.key, score: entry.value, isCurrent: currentPlayer == entry.key, isMe: localUsername == entry.key)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('نقاط الدور الحالي: $currentTurnScore', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                    if (selectedDiceScore > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text('+ $selectedDiceScore', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isCurrentSelectionValid ? Theme.of(context).colorScheme.primary : Colors.redAccent)),
                      ),
                  ],
                ),
                if (isMyTurn)
                  IconButton(
                    icon: Icon(Icons.casino, color: Theme.of(context).colorScheme.secondary),
                    onPressed: _showDiceSelectionModal,
                    tooltip: 'تخصيص النرد',
                  )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const horizontalPadding = 16.0;
        const maxDiceWidth = 60.0;
        const minDiceWidth = 40.0;
        const baseSpacing = 10.0;
        final keptAreaY = constraints.maxHeight - maxDiceWidth - 10;
        final rollingCenterY = constraints.maxHeight * 0.35;
        final availableWidth = constraints.maxWidth - 2 * horizontalPadding;
        final keptDiceIndices = <int>[];
        final rollingDiceIndices = <int>[];
        for (int i = 0; i < dice.length; i++) {
          (diceKept[i] ? keptDiceIndices : rollingDiceIndices).add(i);
        }
        final keptCount = keptDiceIndices.length;
        final spacingCount = (keptCount > 1) ? keptCount - 1 : 0;
        final idealWidth = (availableWidth - (baseSpacing * spacingCount)) / (keptCount == 0 ? 1 : keptCount);
        final keptDiceWidth = idealWidth.clamp(minDiceWidth, maxDiceWidth);
        final keptDiceSpacing = keptCount > 1
            ? (availableWidth - (keptDiceWidth * keptCount)) / spacingCount
            : 0.0;
        return Stack(
          children: List.generate(dice.length, (i) {
            final isKept = diceKept[i];
            double top, left;
            double diceWidth = maxDiceWidth;
            if (isKept) {
              final keptIndex = keptDiceIndices.indexOf(i);
              top = keptAreaY;
              left = horizontalPadding + (keptIndex * (keptDiceWidth + keptDiceSpacing));
              diceWidth = keptDiceWidth;
            } else {
              final rollingIndex = rollingDiceIndices.indexOf(i);
              final row = rollingIndex ~/ 3;
              final col = rollingIndex % 3;
              const rollingDiceSpacing = 15.0;
              final rollingGridWidth = (3 * maxDiceWidth) + (2 * rollingDiceSpacing);
              top = rollingCenterY + (row * (maxDiceWidth + rollingDiceSpacing));
              left = (constraints.maxWidth - rollingGridWidth) / 2 + (col * (maxDiceWidth + rollingDiceSpacing));
            }
            return AnimatedPositioned(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              top: top,
              left: left,
              child: SizedBox(
                width: diceWidth,
                height: diceWidth,
                child: DiceWidget(
                  dice: dice[i],
                  isSelected: diceSelected[i],
                  isKept: diceKept[i],
                  isRolling: isRolling,
                  animation: _rollController,
                  onTap: isMyTurn ? () => toggleDiceSelection(i) : null,
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildControlsArea() {
    final bool canRoll = isCurrentSelectionValid && !isRolling && isMyTurn;
    final bool canEnd = (hasRolled || currentTurnScore > 0) && !isRolling && isMyTurn;
    final bool canInitialRoll = !hasRolled && !isRolling && isMyTurn;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GlassCard(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (canInitialRoll)
                   Expanded(child: GameButton(label: 'رمي النرد', onPressed: _initialRoll, isPrimary: true))
                else
                   Expanded(child: GameButton(label: 'رمي مرة أخرى', onPressed: canRoll ? _rollDiceAction : null, isPrimary: true)),
                const SizedBox(width: 12),
                Expanded(child: GameButton(label: 'إنهاء الدور', onPressed: canEnd ? () => endTurn() : null)),
              ],
            ),
            const SizedBox(height: 16),
            _buildResetButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildResetButton() {
    final bool haveIVoted = resetVotes.contains(localUsername);
    final String voteText = 'تصويت لإعادة الضبط (${resetVotes.length}/${playerScores.length})';
    return GameButton(
      label: voteText,
      onPressed: haveIVoted ? null : () => _firebaseService.voteToResetFarkleGame(groupName!),
      isPrimary: false,
    );
  }

  // FIX: Simplified prompt widget, removing the redundant Row for proper centering.
  Widget _buildJoinGamePrompt() {
    return GlassCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('انضم إلى لعبة فاركل', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 24),
          GameButton(label: 'انضمام', onPressed: joinGame, isPrimary: true),
        ],
      ),
    );
  }

  Widget _buildWaitingPrompt() {
    return GlassCard(
      child: Text('في انتظار بدء اللعبة...', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface)),
    );
  }

  Widget _buildStartButton() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: GameButton(label: 'ابدأ اللعبة', onPressed: startGame, isPrimary: true, isLarge: true),
    );
  }
}