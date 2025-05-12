// Flutter imports
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GroupFirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Get all users in a group and their colors
  Future<Map<String, dynamic>> getGroupUsers(String groupName) async {
    try {
      final groupRef = _firestore.collection('Groups').doc(groupName);
      final groupSnapshot = await groupRef.get();
      
      if (groupSnapshot.exists) {
        final groupData = groupSnapshot.data();
        return groupData?['Users'] ?? {};
      }
      
      return {};
    } catch (e) {
      print('Error getting group users: $e');
      return {};
    }
  }

    // Check if a specific color is taken in a group
  Future<bool> isColorTaken(String groupName, String color, {String? excludeUser}) async {
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
      print('Error checking if color is taken: $e');
      return false;
    }
  }

  // Join or create a group
  Future<bool> joinGroup(String groupName, String userName, String colorValue) async {
    if (groupName.isEmpty || userName.isEmpty) {
      print('Group name or user name is empty');
      return false;
    }

    try {
      final groupRef = _firestore.collection('Groups').doc(groupName);

      // Check if the group exists
      final groupSnapshot = await groupRef.get();

      if (groupSnapshot.exists) {
        // Group exists, check if user is already in the group
        final Map<String, dynamic> users = groupSnapshot.data()?['Users'] ?? {};
        final bool userExists = users.containsKey(userName);
        
        // Check if the color is taken by another user
        final bool colorIsTaken = await isColorTaken(groupName, colorValue, excludeUser: userName);
        
        if (colorIsTaken) {
          print('Color is already taken');
          return false;
        }
        
        // Update the group with the new user and their color
        await groupRef.update({
          'Users': {
            ...users,
            userName: colorValue,
          },
        });
        
        return true;
      } else {
        // Group does not exist, create a new group
        await groupRef.set({
          'Users': {
            userName: colorValue,
          },
        });
        
        return true;
      }
    } catch (e) {
      print('Error joining group: $e');
      return false;
    }
  }
  
  // Update user's color in a group
  Future<bool> updateUserColor(String groupName, String userName, String newColor) async {
    if (groupName.isEmpty || userName.isEmpty) {
      print('Group name or user name is empty');
      return false;
    }
    
    try {
      final groupRef = _firestore.collection('Groups').doc(groupName);
      final groupSnapshot = await groupRef.get();
      
      if (groupSnapshot.exists) {
        // Check if the user exists in the group
        final Map<String, dynamic> users = groupSnapshot.data()?['Users'] ?? {};
        
        if (!users.containsKey(userName)) {
          print('User not found in the group');
          return false;
        }
        
        // Check if the color is taken by another user
        final bool colorIsTaken = await isColorTaken(groupName, newColor, excludeUser: userName);
        
        if (colorIsTaken) {
          print('Color is already taken');
          return false;
        }
        
        // Update the user's color
        users[userName] = newColor;
        
        await groupRef.update({
          'Users': users,
        });
        
        return true;
      }
      
      return false;
    } catch (e) {
      print('Error updating user color: $e');
      return false;
    }
  }
  
  // Remove user from a group
  Future<bool> leaveGroup(String groupName, String userName) async {
    if (groupName.isEmpty || userName.isEmpty) {
      print('Group name or user name is empty');
      return false;
    }
    
    try {
      final groupRef = _firestore.collection('Groups').doc(groupName);
      final groupSnapshot = await groupRef.get();
      
      if (groupSnapshot.exists) {
        // Check if the user exists in the group
        final Map<String, dynamic> users = groupSnapshot.data()?['Users'] ?? {};
        
        if (!users.containsKey(userName)) {
          print('User not found in the group');
          return false;
        }
        
        // Remove the user from the group
        users.remove(userName);
        
        // If there are no more users, delete the group
        if (users.isEmpty) {
          await groupRef.delete();
        } else {
          await groupRef.update({
            'Users': users,
          });
        }
        
        return true;
      }
      
      return false;
    } catch (e) {
      print('Error leaving group: $e');
      return false;
    }
  }
  
  // Listen to changes in a group
  Stream<Map<String, dynamic>> streamGroupUsers(String groupName) {
    return _firestore
        .collection('Groups')
        .doc(groupName)
        .snapshots()
        .map((snapshot) {
          if (snapshot.exists) {
            final data = snapshot.data();
            return data?['Users'] ?? {};
          }
          return <String, dynamic>{};
        });
  }
}