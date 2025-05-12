// Flutter imports
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences
import 'firebase.dart'; // Assuming your GroupFirebaseService is here

// --- Helper Functions for Color Conversion ---

// Converts a Color object to a HEX string (e.g., #RRGGBB)
String colorToHexString(Color color) {
  return '#${(color.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

// Converts a HEX string (e.g., #RRGGBB) to a Color object
Color hexStringToColor(String hexString) {
  final buffer = StringBuffer();
  if (hexString.length == 6 || hexString.length == 7) buffer.write('ff'); // Add alpha if missing (assume opaque)
  buffer.write(hexString.replaceFirst('#', ''));
  try {
    return Color(int.parse(buffer.toString(), radix: 16));
  } catch (e) {
    print("Error parsing hex color: $hexString. Returning black. Error: $e");
    return Colors.black; // Fallback color in case of error
  }
}


class GroupSettingsPage extends StatefulWidget {
  const GroupSettingsPage({super.key});

  @override
  GroupSettingsPageState createState() => GroupSettingsPageState();
}


class GroupSettingsPageState extends State<GroupSettingsPage> {
  final userNameController = TextEditingController();
  final groupNameController = TextEditingController();

  bool inGroup = false;
  // --- Store selected color as HEX string ---
  String selectedColor = '#000000'; // Default color black as HEX string
  final List<Color> colorOptions = [
    Color(0xFF8D6E63), // Brown
    Color(0xFF7E57C2), // Purple
    Color(0xFF26A69A), // Teal
    Color(0xFFFFB74D), // Orange
    Color(0xFF5C6BC0), // Indigo
    Color(0xFFD4E157), // Lime
  ];

  late final GroupFirebaseService _firebaseService;
  // --- groupUsers will now store { username: hexColorString } ---
  Map<String, dynamic> groupUsers = {};
  bool isLoading = false;

  static const String _prefUserNameKey = 'userName';
  static const String _prefGroupNameKey = 'groupName';
  static const String _prefSelectedColorKey = 'selectedColor'; // Stores HEX string
  static const String _prefInGroupKey = 'inGroup';


  @override
  void initState() {
    super.initState();
    _firebaseService = GroupFirebaseService();
    _loadPreferences();
  }

   @override
  void dispose() {
    userNameController.dispose();
    groupNameController.dispose();
    super.dispose();
  }

   Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userNameController.text = prefs.getString(_prefUserNameKey) ?? '';
      groupNameController.text = prefs.getString(_prefGroupNameKey) ?? '';
      // --- Load HEX string, provide default HEX ---
      String loadedColorString = prefs.getString(_prefSelectedColorKey) ?? '#000000';

      // --- Backward Compatibility: Check if old format exists and convert ---
      if (loadedColorString.startsWith('Color(')) {
          try {
              // Extract hex value from "Color(0x...)"
              int value = int.parse(loadedColorString.split('(0x')[1].split(')')[0], radix: 16);
              selectedColor = colorToHexString(Color(value)); // Convert to new HEX format
              // Optionally re-save in new format immediately
              prefs.setString(_prefSelectedColorKey, selectedColor);
              print("Converted old color format $loadedColorString to $selectedColor");
          } catch (e) {
              print("Error converting old color format: $loadedColorString. Using default #000000. Error: $e");
              selectedColor = '#000000'; // Fallback to default HEX
          }
      } else {
          // Assume it's already in HEX format (or the default)
          selectedColor = loadedColorString;
      }
      // --- End Backward Compatibility ---

      inGroup = prefs.getBool(_prefInGroupKey) ?? false;
    });
    if (groupNameController.text.isNotEmpty) {
      await _fetchGroupUsers(groupNameController.text.trim());
    }
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefUserNameKey, userNameController.text.trim());
    await prefs.setString(_prefGroupNameKey, groupNameController.text.trim());
    // --- Save the HEX string ---
    await prefs.setString(_prefSelectedColorKey, selectedColor);
    await prefs.setBool(_prefInGroupKey, inGroup);
  }

  Future<void> _fetchGroupUsers(String groupName) async {
     if (groupName.isEmpty) return;
     setState(() {
       isLoading = true;
       groupUsers = {};
     });
     try {
        // Assuming getGroupUsers returns a map like { username: hexColorString }
        final users = await _firebaseService.getGroupUsers(groupName);
        if (mounted) {
            setState(() {
              // Store the map directly (values are expected to be HEX strings from Firestore)
              groupUsers = users;
              final currentUser = userNameController.text.trim();
              if (currentUser.isNotEmpty && groupUsers.containsKey(currentUser)) {
                  // Firestore stores the HEX string, compare directly
                  final storedColorForUser = groupUsers[currentUser].toString();
                  // We could update selectedColor if the stored one is different,
                  // but let's keep the locally selected one unless join/update fails.
                  // Example: selectedColor = storedColorForUser;
              } else if (currentUser.isNotEmpty && !groupUsers.containsKey(currentUser)) {
                  inGroup = false;
                  _savePreferences();
              }
            });
        }
     } catch (e) {
        print("Error fetching group users: $e");
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('خطأ في البحث عن المجموعة: $e')),
            );
        }
     } finally {
        if (mounted) {
            setState(() {
              isLoading = false;
            });
        }
     }
  }


  // --- (Keep userNameField, groupField methods - No changes needed here) ---
  Widget userNameField() {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'اسم اللاعب',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          SizedBox(height: 8),
          TextField(
            controller: userNameController,
            decoration: InputDecoration(
              floatingLabelBehavior: FloatingLabelBehavior.never,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
             onEditingComplete: () {
                 _savePreferences();
                 FocusScope.of(context).unfocus();
             },
          ),
        ],
      ),
    );
  }

  Widget groupField() {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'اسم المجموعة',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          SizedBox(height: 8),
          TextField(
            controller: groupNameController,
            decoration: InputDecoration(
              floatingLabelBehavior: FloatingLabelBehavior.never,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: IconButton(
                icon: Icon(Icons.search),
                onPressed: isLoading ? null : () async {
                   final groupName = groupNameController.text.trim();
                   await _fetchGroupUsers(groupName);
                   _savePreferences();
                },
              ),
            ),
            onSubmitted: (value) async {
               final groupName = value.trim();
               await _fetchGroupUsers(groupName);
               _savePreferences();
            },
            onEditingComplete: () {
                 _savePreferences();
             },
          ),
        ],
      ),
    );
  }


  // Helper function to get username for a color (compares HEX strings)
  String? _getUserForColor(String hexColorString) {
    // Ensure comparison is case-insensitive for HEX strings if needed, though ours are standardized
    final targetHex = hexColorString.toUpperCase();
    for (final entry in groupUsers.entries) {
      // Assume entry.value is the HEX string from Firestore
      if (entry.value is String && (entry.value as String).toUpperCase() == targetHex) {
        return entry.key; // Return the username (key)
      }
    }
    return null; // No user has this color
  }


  // --- UPDATED: roleSelection widget ---
  Widget roleSelection(context) {
    final currentUserName = userNameController.text.trim();

    Widget colorButton(BuildContext context, Color colorOption) {
      // --- Convert the Color option to HEX for logic ---
      String hexColorString = colorToHexString(colorOption);
      String? takerUserName = _getUserForColor(hexColorString); // Find who took this color (using HEX)

      // --- Comparisons use HEX strings ---
      bool isSelectedByMe = selectedColor.toUpperCase() == hexColorString.toUpperCase();
      bool isTakenByOther = takerUserName != null && takerUserName != currentUserName;

      // --- Use the original Color object for display ---
      Color displayColor = colorOption;

      return OutlinedButton(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          // --- Use the Color object for background ---
          backgroundColor: displayColor,
          side: isSelectedByMe
              ? BorderSide(color: Theme.of(context).colorScheme.onPrimaryContainer, width: 3)
              : BorderSide.none,
          padding: EdgeInsets.zero,
        ),
        onPressed: isTakenByOther || isLoading
            ? null
            : () async {
                // --- Update state with HEX string ---
                setState(() {
                  selectedColor = hexColorString;
                });
                await _savePreferences(); // Save HEX selection immediately

                if (inGroup && currentUserName.isNotEmpty && groupNameController.text.isNotEmpty) {
                  setState(() => isLoading = true);
                  try {
                    // --- Pass HEX string to Firebase service ---
                    // !!! IMPORTANT: Ensure _firebaseService.updateUserColor saves the hexColorString !!!
                    await _firebaseService.updateUserColor(
                      groupNameController.text.trim(),
                      currentUserName,
                      selectedColor, // Pass the HEX string
                    );
                    await _fetchGroupUsers(groupNameController.text.trim());
                  } catch (e) {
                    print("Error updating color: $e");
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('خطأ في تحديث اللون: $e')),
                      );
                    }
                  } finally {
                    if (mounted) {
                      setState(() => isLoading = false);
                    }
                  }
                }
              },
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: double.infinity,
              height: 45,
              decoration: BoxDecoration(
                 borderRadius: BorderRadius.circular(12),
              ),
            ),
            if (takerUserName != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  takerUserName,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    shadows: [
                       Shadow(
                         blurRadius: 2.0,
                         color: Colors.black.withOpacity(0.5),
                         offset: Offset(1.0, 1.0),
                       ),
                    ]
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'اختار اللون',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          SizedBox(height: 16),
          if (isLoading && groupUsers.isEmpty)
            const Center(child: CircularProgressIndicator())
          else if (!isLoading && groupNameController.text.isNotEmpty && groupUsers.isEmpty)
            const Center(child: Text('المجموعة غير موجودة أو فارغة.'))
          else if (groupNameController.text.isEmpty)
             const Center(child: Text('ابحث عن مجموعة لعرض الألوان المتاحة.'))
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 2.2,
              ),
              itemCount: colorOptions.length,
              itemBuilder: (context, index) {
                // Pass the Color object from the list
                return colorButton(context, colorOptions[index]);
              },
            )
        ],
      ),
    );
  }


  // --- UPDATED: saveButton method ---
   Widget saveButton(context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            shape: const StadiumBorder(),
            padding: const EdgeInsets.all(12),
          ),
          onPressed: isLoading || userNameController.text.trim().isEmpty || groupNameController.text.trim().isEmpty
              ? null
              : () async {
                  final groupName = groupNameController.text.trim();
                  final userName = userNameController.text.trim();
                  // --- selectedColor is already the HEX string ---
                  final colorToJoinWith = selectedColor;

                   final String? taker = _getUserForColor(colorToJoinWith); // Check using HEX string
                   if (taker != null && taker != userName) {
                       if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('هذا اللون محجوز بواسطة $taker. الرجاء اختيار لون آخر.')),
                            );
                       }
                       return;
                   }

                  // --- Check if a non-default HEX color was selected ---
                  // Also check if black is even an option if #000000 is selected.
                  bool isBlackAnOption = colorOptions.any((c) => colorToHexString(c) == '#000000');
                  if (colorToJoinWith == '#000000' && !isBlackAnOption) {
                     if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('الرجاء اختيار لون للمجموعة (غير اللون الافتراضي)')),
                            );
                       }
                       return;
                  }


                  setState(() => isLoading = true);

                  try {
                     // --- Pass HEX string to Firebase service ---
                     // !!! IMPORTANT: Ensure _firebaseService.joinGroup saves the colorToJoinWith (HEX string) !!!
                    final success = await _firebaseService.joinGroup(
                      groupName,
                      userName,
                      colorToJoinWith, // Pass the HEX string
                    );

                    if (success && mounted) {
                      setState(() {
                        inGroup = true;
                      });
                      await _savePreferences(); // Saves HEX string
                      await _fetchGroupUsers(groupName); // Refreshes users (with HEX strings)
                      ScaffoldMessenger.of(context).showSnackBar(
                         SnackBar(content: Text(inGroup ? 'تم تحديث المعلومات بنجاح!' : 'تم الانضمام للمجموعة بنجاح!')),
                       );
                    } else if (!success && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                         SnackBar(content: Text('فشل الانضمام أو التحديث. قد يكون اللون محجوزاً أو حدث خطأ.')),
                       );
                        await _fetchGroupUsers(groupName);
                    }
                  } catch(e) {
                      print("Error joining/updating group: $e");
                       if (mounted) {
                           ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('حدث خطأ: $e')),
                          );
                       }
                  }
                  finally {
                     if (mounted) {
                        setState(() => isLoading = false);
                     }
                  }
                },
          child: isLoading
                ? const SizedBox( height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(inGroup ? 'تحديث المعلومات' : 'انضم للمجموعة'),
        ),
      ),
    );
  }


  // --- _isColorTaken method now uses HEX strings ---
  // (Less critical now with direct user display, but updated for consistency)
  bool _isColorTaken(String hexColorString) {
     final currentUserName = userNameController.text.trim();
     // _getUserForColor works with HEX strings
     final taker = _getUserForColor(hexColorString);
     return taker != null && taker != currentUserName;
  }

  // --- (Keep build method - No changes needed here) ---
   @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('إعدادات المجموعة'),
        automaticallyImplyLeading: false
        ),
      body: GestureDetector(
         onTap: () => FocusScope.of(context).unfocus(),
         child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              userNameField(),
              SizedBox(height: 16),
              groupField(),
              SizedBox(height: 24),
              roleSelection(context),
              SizedBox(height: 24),
              saveButton(context),
            ],
          ),
        ),
       ),
    );
  }
}