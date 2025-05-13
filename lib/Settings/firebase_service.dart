import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  Future<String?> getPuzzleProgress(
    String groupName,
    String puzzleNumber,
  ) async {
    final doc = await _getPuzzleDocRef(groupName, puzzleNumber).get();
    if (doc.exists) {
      return doc['progress'] as String?;
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
