import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

// ===== Farkle METHODS =====

DocumentReference _getFarkleGameRef(String groupName) {
  return _firestore.collection('groups').doc(groupName).collection('games').doc('farkle');
}

Future<bool> joinFarkleGame(String groupName) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('userName');
    if (username == null || username.isEmpty) return false;

    final gameRef = _getFarkleGameRef(groupName);

    await _firestore.runTransaction((transaction) async {
      final gameDoc = await transaction.get(gameRef);

      Map<String, dynamic> gameData = {};
      if (gameDoc.exists) {
        gameData = gameDoc.data() as Map<String, dynamic>;
      }

      Map<String, int> playerScores = Map<String, int>.from(gameData['playerScores'] ?? {});
      List<String> playerOrder = List<String>.from(gameData['playerOrder'] ?? []);
      
      // NEW: Handle player dice configurations
      Map<String, dynamic> playerDiceConfigs = Map<String, dynamic>.from(gameData['playerDiceConfigs'] ?? {});

      if (!playerScores.containsKey(username)) {
        playerScores[username] = 0;
        playerOrder.add(username);
        
        // NEW: Set default dice config for new player
        playerDiceConfigs[username] = List.generate(6, (_) => 'standard');

        gameData['playerScores'] = playerScores;
        gameData['playerOrder'] = playerOrder;
        gameData['playerDiceConfigs'] = playerDiceConfigs; // Add to data
        gameData.putIfAbsent('gameStarted', () => false);
        gameData.putIfAbsent('currentPlayer', () => playerOrder.first);
        gameData.putIfAbsent('currentTurnIndex', () => 0);

        transaction.set(gameRef, gameData, SetOptions(merge: true));
      }
    });
    return true;
  } catch (e) {
    // ignore: avoid_print
    print('Error joining Farkle game: $e');
    return false;
  }
}

// NEW: Method to save a player's dice choices to Firebase
Future<void> updatePlayerDiceConfig(String groupName, List<String> diceTypeIds) async {
  final prefs = await SharedPreferences.getInstance();
  final username = prefs.getString('userName');
  if (username == null) return;
  
  final gameRef = _getFarkleGameRef(groupName);
  // Use dot notation for efficient update of a nested field
  await gameRef.update({
    'playerDiceConfigs.$username': diceTypeIds
  });
}

Stream<Map<String, dynamic>> listenToFarkleGame(String groupName) {
  return _getFarkleGameRef(groupName).snapshots().map((snapshot) {
    return snapshot.exists ? snapshot.data() as Map<String, dynamic> : {};
  });
}

void listenToFarkleGameWithCallback(String groupName, Function(Map<String, dynamic>) onUpdate,) {
  listenToFarkleGame(groupName).listen(onUpdate);
}

Future<void> startFarkleGame(String groupName) async {
  await _getFarkleGameRef(groupName).update({
    'gameStarted': true,
    'resetVotes': FieldValue.delete(),
  });
}

Future<void> updatePlayerScore(String groupName, int scoreToAdd) async {
  final prefs = await SharedPreferences.getInstance();
  final username = prefs.getString('userName');
  if (username == null) return;

  final gameRef = _getFarkleGameRef(groupName);

  await _firestore.runTransaction((transaction) async {
    final gameDoc = await transaction.get(gameRef);
    if (gameDoc.exists) {
      final gameData = gameDoc.data() as Map<String, dynamic>;
      final playerScores = Map<String, int>.from(gameData['playerScores']);
      playerScores[username] = (playerScores[username] ?? 0) + scoreToAdd;
      transaction.update(gameRef, {'playerScores': playerScores});
    }
  });
}

Future<void> updateFarkleTurnState(String groupName, Map<String, dynamic> turnState,) async {
  await _getFarkleGameRef(groupName).update({'turnState': turnState});
}

Future<void> endPlayerTurn(String groupName) async {
  final gameRef = _getFarkleGameRef(groupName);

  await _firestore.runTransaction((transaction) async {
    final gameDoc = await transaction.get(gameRef);
    if (gameDoc.exists) {
      final gameData = gameDoc.data() as Map<String, dynamic>;
      final playerOrder = List<String>.from(gameData['playerOrder']);
      final currentTurnIndex = gameData['currentTurnIndex'] ?? 0;

      if (playerOrder.isNotEmpty) {
        final nextTurnIndex = (currentTurnIndex + 1) % playerOrder.length;
        final nextPlayer = playerOrder[nextTurnIndex];

        transaction.update(gameRef, {
          'currentPlayer': nextPlayer,
          'currentTurnIndex': nextTurnIndex,
          'turnState': FieldValue.delete(),
        });
      }
    }
  });
}

Future<void> voteToResetFarkleGame(String groupName) async {
  final prefs = await SharedPreferences.getInstance();
  final username = prefs.getString('userName');
  if (username == null) return;

  final gameRef = _getFarkleGameRef(groupName);

  await _firestore.runTransaction((transaction) async {
    final gameDoc = await transaction.get(gameRef);
    if (!gameDoc.exists) return;

    final gameData = gameDoc.data() as Map<String, dynamic>;
    final playerOrder = List<String>.from(gameData['playerOrder'] ?? []);
    List<String> resetVotes = List<String>.from(gameData['resetVotes'] ?? []);

    if (!resetVotes.contains(username)) {
      resetVotes.add(username);
    }

    if (playerOrder.isNotEmpty && resetVotes.length >= playerOrder.length) {
      Map<String, int> playerScores = Map<String, int>.from(gameData['playerScores']);
      playerScores.updateAll((key, value) => 0);

      transaction.update(gameRef, {
        'playerScores': playerScores,
        'resetVotes': FieldValue.delete(),
      });
    } else {
      transaction.update(gameRef, {'resetVotes': resetVotes});
    }
  });
}

  // ===== GROUP METHODS =====

  // Get all users in a group and their colors
  Future<Map<String, dynamic>> getGroupUsers(String groupName) async {
    try {
      final groupRef = _firestore.collection(groupName).doc(groupName);
      final groupSnapshot = await groupRef.get();

      if (groupSnapshot.exists) {
        final groupData = groupSnapshot.data();
        return groupData?['users'] ?? {};
      }

      return {};
    } catch (e) {
      return {};
    }
  }

  // Check if a specific color is taken in a group
  Future<bool> isColorTaken(
    String groupName,
    String color, {
    String? excludeUser,
  }) async {
    try {
      final users = await getGroupUsers(groupName);

      for (final user in users.entries) {
        // Skip checking the excluded user
        if (excludeUser != null && user.key == excludeUser) continue;

        if (user.value == color) {
          return true;
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  // Join or create a group
  Future<bool> joinGroup(
    String groupName,
    String userName,
    String colorValue,
  ) async {
    if (groupName.isEmpty || userName.isEmpty) {
      return false;
    }

    try {
      final groupRef = _firestore.collection(groupName).doc(groupName);

      // Check if the group exists
      final groupSnapshot = await groupRef.get();

      if (groupSnapshot.exists) {
        // Group exists, check if user is already in the group
        final Map<String, dynamic> users = groupSnapshot.data()?['users'] ?? {};

        // Check if the color is taken by another user
        final bool colorIsTaken = await isColorTaken(
          groupName,
          colorValue,
          excludeUser: userName,
        );

        if (colorIsTaken) {
          return false;
        }

        // Update the group with the new user and their color
        await groupRef.update({
          'users': {...users, userName: colorValue},
        });

        return true;
      } else {
        // Group does not exist, create a new group
        await groupRef.set({
          'users': {userName: colorValue},
        });

        return true;
      }
    } catch (e) {
      return false;
    }
  }

  // Update user's color in a group
  Future<bool> updateUserColor(
    String groupName,
    String userName,
    String newColor,
  ) async {
    if (groupName.isEmpty || userName.isEmpty) {
      return false;
    }

    try {
      final groupRef = _firestore.collection(groupName).doc(groupName);
      final groupSnapshot = await groupRef.get();

      if (groupSnapshot.exists) {
        // Check if the user exists in the group
        final Map<String, dynamic> users = groupSnapshot.data()?['users'] ?? {};

        if (!users.containsKey(userName)) {
          return false;
        }

        // Check if the color is taken by another user
        final bool colorIsTaken = await isColorTaken(
          groupName,
          newColor,
          excludeUser: userName,
        );

        if (colorIsTaken) {
          return false;
        }

        // Update the user's color
        users[userName] = newColor;

        await groupRef.update({'users': users});

        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  // Remove user from a group
  Future<bool> leaveGroup(String groupName, String userName) async {
    if (groupName.isEmpty || userName.isEmpty) {
      return false;
    }

    try {
      final groupRef = _firestore.collection(groupName).doc(groupName);
      final groupSnapshot = await groupRef.get();

      if (groupSnapshot.exists) {
        // Check if the user exists in the group
        final Map<String, dynamic> users = groupSnapshot.data()?['users'] ?? {};

        if (!users.containsKey(userName)) {
          return false;
        }

        // Remove the user from the group
        users.remove(userName);

        // If there are no more users, delete the group
        if (users.isEmpty) {
          await groupRef.delete();
        } else {
          await groupRef.update({'users': users});
        }

        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  // Listen to changes in a group
  Stream<Map<String, dynamic>> streamGroupUsers(String groupName) {
    return _firestore.collection(groupName).doc(groupName).snapshots().map((
      snapshot,
    ) {
      if (snapshot.exists) {
        final data = snapshot.data();
        return data?['users'] ?? {};
      }
      return <String, dynamic>{};
    });
  }

  // ===== PUZZLE METHODS =====

  // Get the reference to a puzzle document
  DocumentReference _getPuzzleDocRef(String groupName, String puzzleNumber) {
    return _firestore
        .collection(groupName)
        .doc(groupName)
        .collection('puzzles')
        .doc(puzzleNumber);
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getPuzzleDoc(
    String groupName,
    String puzzleNumber,
  ) {
    return _getPuzzleDocRef(
      groupName,
      puzzleNumber,
    ).get().then((doc) => doc as DocumentSnapshot<Map<String, dynamic>>);
  }

  Future<String?> getPuzzleProgress(
    String groupName,
    String puzzleNumber,
  ) async {
    final doc = await _getPuzzleDocRef(groupName, puzzleNumber).get();
    final data = doc.data() as Map<String, dynamic>?;
    if (doc.exists && data != null && data.containsKey('progress')) {
      return data['progress'] as String?;
    }
    return null;
  }

  // Get puzzle progress for a group
  Stream<Map<String, dynamic>> streamPuzzleProgress(
    String groupName,
    String puzzleNumber,
  ) {
    return _getPuzzleDocRef(groupName, puzzleNumber).snapshots().map((
      snapshot,
    ) {
      if (snapshot.exists) {
        return snapshot.data() as Map<String, dynamic>;
      }
      return {};
    });
  }

  // Batch update multiple cells (e.g., when syncing local data)
  Future<void> updatePuzzleProgressBatch(
    String groupName,
    String puzzleNumber,
    Map<String, dynamic> progressData,
  ) async {
    final docRef = _getPuzzleDocRef(groupName, puzzleNumber);
    // Firestore's set with merge:true handles batch updates efficiently if the map keys are field paths
    // Ensure progressData keys are in 'r_c' format
    await docRef.set(progressData, SetOptions(merge: true));
  }

  // Update active user
  Future<void> updateActiveUser(
    String groupName,
    String puzzleNumber,
    String userName,
  ) async {
    final docRef = _getPuzzleDocRef(groupName, puzzleNumber);
    final now = DateTime.now().toIso8601String();

    await docRef.set({
      'active': {userName: now},
    }, SetOptions(merge: true));
  }

  // Update metadata like 'progress' status
  Future<void> updatePuzzleMetadata(
    String groupName,
    String puzzleNumber,
    Map<String, dynamic> metadata,
  ) async {
    final docRef = _getPuzzleDocRef(groupName, puzzleNumber);
    await docRef.set(metadata, SetOptions(merge: true));
  }

  // Update cell in puzzle
  Future<bool> updatePuzzleCell(
    String groupName,
    String puzzleNumber,
    int row,
    int col,
    String char,
    String userName,
  ) async {
    try {
      final docRef = _getPuzzleDocRef(groupName, puzzleNumber);

      // Create a cell key in format "row_col"
      final cellKey = '${row}_$col';

      await docRef.set({
        cellKey: {'char': char, 'madeBy': userName},
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      return false;
    }
  }

  // Reset puzzle progress
  Future<bool> resetPuzzleProgress(
    String groupName,
    String puzzleNumber,
  ) async {
    try {
      await _getPuzzleDocRef(groupName, puzzleNumber).delete();
      return true;
    } catch (e) {
      return false;
    }
  }
}
