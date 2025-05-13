import 'package:cloud_firestore/cloud_firestore.dart';

class PuzzleFirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Get puzzle progress for a group
  Stream<Map<String, dynamic>> streamPuzzleProgress(String groupName, String puzzleNumber) {
    return _firestore
        .collection('Groups')
        .doc(groupName)
        .collection('Puzzles')
        .doc(puzzleNumber)
        .snapshots()
        .map((snapshot) {
          if (snapshot.exists) {
            return snapshot.data() as Map<String, dynamic>;
          }
          return {};
        });
  }

    // Get the path for a specific puzzle's progress within a group
  DocumentReference getPuzzleDocRef(String groupName, String puzzleNumber) {
    // Example path: /groups/{groupName}/puzzles/{puzzleNumber}
    return _firestore.collection('groups').doc(groupName).collection('puzzles').doc(puzzleNumber);
  }

    // Get the path for a specific puzzle's progress within a group
  DocumentReference _getPuzzleDocRef(String groupName, String puzzleNumber) {
    // Example path: /groups/{groupName}/puzzles/{puzzleNumber}
    return _firestore.collection('groups').doc(groupName).collection('puzzles').doc(puzzleNumber);
  }

    // Batch update multiple cells (e.g., when syncing local data)
  Future<void> updatePuzzleProgressBatch(String groupName, String puzzleNumber, Map<String, dynamic> progressData) async {
     final docRef = _getPuzzleDocRef(groupName, puzzleNumber);
     // Firestore's set with merge:true handles batch updates efficiently if the map keys are field paths
     // Ensure progressData keys are in 'r_c' format
     await docRef.set(progressData, SetOptions(merge: true));
  }
  
    // Update metadata like 'progress' status
  Future<void> updatePuzzleMetadata(String groupName, String puzzleNumber, Map<String, dynamic> metadata) async {
      final docRef = _getPuzzleDocRef(groupName, puzzleNumber);
      await docRef.set(metadata, SetOptions(merge: true));
  }
  // Update cell in puzzle
  Future<bool> updatePuzzleCell(String groupName, String puzzleNumber, 
      int row, int col, String char, String userName) async {
    try {
      final docRef = _firestore
          .collection('Groups')
          .doc(groupName)
          .collection('Puzzles')
          .doc(puzzleNumber);
          
      // Create a cell key in format "row_col"
      final cellKey = '${row}_$col';
      
      await docRef.set({
        cellKey: {
          'char': char,
          'madeBy': userName
        }
      }, SetOptions(merge: true));
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  // Reset puzzle progress
  Future<bool> resetPuzzleProgress(String groupName, String puzzleNumber) async {
    try {
      await _firestore
          .collection('Groups')
          .doc(groupName)
          .collection('Puzzles')
          .doc(puzzleNumber)
          .delete();
          
      return true;
    } catch (e) {
      return false;
    }
  }
}