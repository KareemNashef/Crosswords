// Flutter imports
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Local imports
import 'package:crosswords/Settings/firebase_service.dart';
import 'package:crosswords/Utilities/color_utils.dart';

// ========== Group Settings Page ========== //

class GroupSettingsPage extends StatefulWidget {
  const GroupSettingsPage({super.key});

  @override
  GroupSettingsPageState createState() => GroupSettingsPageState();
}

class GroupSettingsPageState extends State<GroupSettingsPage> {
  // ===== Class variables =====

  // Controllers
  final userNameController = TextEditingController();
  final groupNameController = TextEditingController();

  // Group Settings
  bool inGroup = false;
  String selectedColor = '#000000';
  final List<Color> colorOptions = [
    Color(0xFF8D6E63), // Brown
    Color(0xFF7E57C2), // Purple
    Color(0xFF26A69A), // Teal
    Color(0xFFFFB74D), // Orange
    Color(0xFF5C6BC0), // Indigo
    Color(0xFFD4E157), // Lime
    Color(0xFF42A5F5), // Blue
    Color(0xFF66BB6A), // Green
    Color(0xFFEC407A), // Pink
  ];
  Map<String, dynamic> groupUsers = {};

  // Firebase service
  late final FirebaseService _firebaseService;

  // Page settings
  bool isLoading = false;
  static const String _prefUserNameKey = 'userName';
  static const String _prefGroupNameKey = 'groupName';
  static const String _prefSelectedColorKey = 'selectedColor';
  static const String _prefInGroupKey = 'inGroup';

  // ===== Class methods =====

  // Initialize page
  @override
  void initState() {
    super.initState();
    _firebaseService = FirebaseService();
    _loadPreferences();
  }

  // Dispose controllers
  @override
  void dispose() {
    userNameController.dispose();
    groupNameController.dispose();
    super.dispose();
  }

  // Load preferences from shared preferences
  Future<void> _loadPreferences() async {
    // Load preferences instance
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      // Load page settings
      userNameController.text = prefs.getString(_prefUserNameKey) ?? '';
      groupNameController.text = prefs.getString(_prefGroupNameKey) ?? '';
      selectedColor = prefs.getString(_prefSelectedColorKey) ?? '#000000';
      inGroup = prefs.getBool(_prefInGroupKey) ?? false;
    });

    // Fetch group users
    if (groupNameController.text.isNotEmpty) {
      await _fetchGroupUsers(groupNameController.text.trim());
    }
  }

  // Save preferences to shared preferences
  Future<void> _savePreferences() async {
    // Load preferences instance
    final prefs = await SharedPreferences.getInstance();

    // Save page settings
    await prefs.setString(_prefUserNameKey, userNameController.text.trim());
    await prefs.setString(_prefGroupNameKey, groupNameController.text.trim());
    await prefs.setString(_prefSelectedColorKey, selectedColor);
    await prefs.setBool(_prefInGroupKey, inGroup);
  }

  // Fetch group users from Firestore
  Future<void> _fetchGroupUsers(String groupName) async {
    // Check if the group name is valid
    if (groupName.isEmpty) return;

    // Start loading state
    setState(() {
      isLoading = true;
      groupUsers = {};
    });

    // Get group users
    final users = await _firebaseService.getGroupUsers(groupName);

    // Update page state
    setState(() {
      groupUsers = users;
      isLoading = false;
    });
  }

  // Get color's user
  String? _getUserForColor(String hexColorString) {
    for (final entry in groupUsers.entries) {
      if (entry.value == hexColorString) {
        return entry.key;
      }
    }
    return null;
  }

  // Join group
  Future<void> _joinGroup() async {
    final groupName = groupNameController.text.trim();
    final userName = userNameController.text.trim();

    setState(() => isLoading = true);

    final success = await _firebaseService.joinGroup(
      groupName,
      userName,
      selectedColor,
    );

    if (success) {
      if (!mounted) return;
      setState(() => inGroup = true);
      await _savePreferences();
      await _fetchGroupUsers(groupName);
      _showSnackBar(
        context,
        inGroup ? 'تم تحديث المعلومات بنجاح!' : 'تم الانضمام للمجموعة بنجاح!',
      );
    } else {
      _showSnackBar(
        context,
        'فشل الانضمام أو التحديث. قد يكون اللون محجوزاً أو حدث خطأ.',
      );
      await _fetchGroupUsers(groupName);
    }

    setState(() => isLoading = false);
  }

  // Leave group
  Future<void> _leaveGroup() async {
    final groupName = groupNameController.text.trim();
    final userName = userNameController.text.trim();

    setState(() => isLoading = true);

    final success = await _firebaseService.leaveGroup(groupName, userName);

    if (success) {
      if (!mounted) return;
      setState(() => inGroup = false);
      await _savePreferences();
      await _fetchGroupUsers(groupName);
      _showSnackBar(context, 'تم مغادرة المجموعة بنجاح!');
    } else {
      _showSnackBar(context, 'أنت لست جزءًا من هذه المجموعة أو حدث خطأ.');
      await _fetchGroupUsers(groupName);
    }

    setState(() => isLoading = false);
  }

  // Show snackbar
  void _showSnackBar(BuildContext context, String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  // ===== Class widgets =====

  Widget userNameField() {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            'اسم اللاعب',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),

          // Padding
          SizedBox(height: 8),

          // TextField
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
          const SizedBox(height: 8),
          TextField(
            controller: groupNameController,
            decoration: InputDecoration(
              hintText: 'أدخل اسم المجموعة',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onSubmitted: (value) async {
              final groupName = value.trim();
              await _fetchGroupUsers(groupName);
              _savePreferences();
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.login),
                  label: const Text('انضم'),
                  onPressed: isLoading ? null : _joinGroup,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('غادر'),
                  onPressed: isLoading ? null : _leaveGroup,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'تحديث المجموعة',
                onPressed:
                    isLoading
                        ? null
                        : () async {
                          final groupName = groupNameController.text.trim();
                          await _fetchGroupUsers(groupName);
                        },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget colorSelection(context) {
    // Get current user
    final currentUserName = userNameController.text.trim();

    Widget colorButton(BuildContext context, Color colorOption) {
      String hexColorString = colorToHexString(colorOption);
      String? takerUserName = _getUserForColor(hexColorString);

      // Check if this color is taken
      bool isSelectedByMe = selectedColor == hexColorString;
      bool isTakenByOther =
          takerUserName != null && takerUserName != currentUserName;

      return OutlinedButton(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: colorOption,
          side:
              isSelectedByMe
                  ? BorderSide(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    width: 3,
                  )
                  : BorderSide.none,
          padding: EdgeInsets.zero,
        ),
        onPressed:
            isTakenByOther || isLoading
                ? null
                : () async {
                  // Update state
                  setState(() {
                    selectedColor = hexColorString;
                    isLoading = true;
                  });

                  // Sync to Firebase
                  await _firebaseService.updateUserColor(
                    groupNameController.text.trim(),
                    currentUserName,
                    selectedColor,
                  );

                  // Update group users
                  await _fetchGroupUsers(groupNameController.text.trim());

                  // Save preferences
                  await _savePreferences();

                  // End loading state
                  setState(() => isLoading = false);
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
              Text(
                takerUserName,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(color: Colors.black, offset: Offset(1.0, 1.0)),
                  ],
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
          // Title
          Text(
            'اختار اللون',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),

          // Padding
          SizedBox(height: 16),

          // Loading
          if (isLoading && groupUsers.isEmpty)
            const Center(child: CircularProgressIndicator())
          // Empty group
          else if (!isLoading &&
              groupNameController.text.isNotEmpty &&
              groupUsers.isEmpty)
            const Center(child: Text('المجموعة غير موجودة أو فارغة.'))
          // No group
          else if (groupNameController.text.isEmpty)
            const Center(child: Text('ابحث عن مجموعة لعرض الألوان المتاحة.'))
          // Colors
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
                return colorButton(context, colorOptions[index]);
              },
            ),
        ],
      ),
    );
  }

  // ===== Build method =====

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('إعدادات المجموعة'),
        automaticallyImplyLeading: false,
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
              SizedBox(height: 16),
              colorSelection(context),
            ],
          ),
        ),
      ),
    );
  }
}
