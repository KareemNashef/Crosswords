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
    const Color(0xFFEF5350), // Red
    const Color(0xFF66BB6A), // Green
    const Color(0xFF42A5F5), // Blue
    const Color(0xFFFFCA28), // Yellow
    const Color(0xFFAB47BC), // Purple
    const Color(0xFFFF7043), // Orange
    const Color(0xFF26C6DA), // Teal
    const Color(0xFF7E57C2), // Deep Purple
    const Color(0xFF8D6E63), // Brown
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

  // ===== Lifecycle Methods =====

  @override
  void initState() {
    super.initState();
    _firebaseService = FirebaseService();
    _loadPreferences();
  }

  @override
  void dispose() {
    userNameController.dispose();
    groupNameController.dispose();
    super.dispose();
  }

  // ===== Data Handling Methods =====

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userNameController.text = prefs.getString(_prefUserNameKey) ?? '';
      groupNameController.text = prefs.getString(_prefGroupNameKey) ?? '';
      selectedColor =
          prefs.getString(_prefSelectedColorKey) ??
          colorToHexString(colorOptions.first);
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
    await prefs.setString(_prefSelectedColorKey, selectedColor);
    await prefs.setBool(_prefInGroupKey, inGroup);
  }

  Future<void> _fetchGroupUsers(String groupName) async {
    if (groupName.isEmpty) return;
    setState(() => isLoading = true);

    final users = await _firebaseService.getGroupUsers(groupName);

    if (!mounted) return;
    setState(() {
      groupUsers = users;
      isLoading = false;
    });
  }

  String? _getUserForColor(String hexColorString) {
    for (final entry in groupUsers.entries) {
      if (entry.value == hexColorString) return entry.key;
    }
    return null;
  }

  Future<void> _handleJoinGroup() async {
    final groupName = groupNameController.text.trim();
    final userName = userNameController.text.trim();
    if (groupName.isEmpty || userName.isEmpty) {
      _showSnackBar('الرجاء إدخال اسم المستخدم واسم المجموعة.');
      return;
    }

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
        inGroup ? 'تم التحديث بنجاح!' : 'انضمت للمجموعة بنجاح!',
      );
    } else {
      _showSnackBar('تعذّر الانضمام أو التحديث. قد يكون اللون غير متاح.');
      await _fetchGroupUsers(groupName);
    }
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _handleLeaveGroup() async {
    final groupName = groupNameController.text.trim();
    final userName = userNameController.text.trim();
    if (groupName.isEmpty || userName.isEmpty) return;

    setState(() => isLoading = true);
    final success = await _firebaseService.leaveGroup(groupName, userName);
    if (success) {
      if (!mounted) return;
      setState(() => inGroup = false);
      // Clear group name from preferences after leaving
      groupNameController.clear();
      groupUsers.clear();
      await _savePreferences();
      _showSnackBar('لقد غادرت المجموعة.');
    } else {
      _showSnackBar('فشل في مغادرة المجموعة.');
    }
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _handleColorSelection(Color color) async {
    setState(() => isLoading = true);

    final newColorHex = colorToHexString(color);
    final groupName = groupNameController.text.trim();
    final userName = userNameController.text.trim();

    final success = await _firebaseService.updateUserColor(
      groupName,
      userName,
      newColorHex,
    );

    if (success) {
      setState(() => selectedColor = newColorHex);
      await _savePreferences();
      await _fetchGroupUsers(groupName);
    } else {
      _showSnackBar('تعذر تحديث اللون. ربما تم التقاطه للتو.');
      await _fetchGroupUsers(groupName);
    }

    if (mounted) setState(() => isLoading = false);
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: Colors.white)),
        ),
      );
    }
  }

  // ===== Build Method =====

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
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
            color: Theme.of(context).colorScheme.primary,
          ),
          title: Text(
            'إعدادات المجموعة',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildUserProfileCard(),
                const SizedBox(height: 24),
                _buildGroupManagementCard(),
                const SizedBox(height: 24),
                _buildColorSelectionCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===== Widget Builders =====

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildUserProfileCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Theme.of(context).cardColor.withOpacity(0.5),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('تعريف المستخدم'),
            const SizedBox(height: 16),
            TextField(
              controller: userNameController,
              decoration: InputDecoration(
                labelText: 'اسم المستخدم',
                floatingLabelBehavior: FloatingLabelBehavior.never,
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onEditingComplete: _savePreferences,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupManagementCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Theme.of(context).cardColor.withOpacity(0.5),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('إدارة المجموعة'),
            const SizedBox(height: 16),
            TextField(
              controller: groupNameController,
              decoration: InputDecoration(
                labelText: 'اسم المجموعة',
                floatingLabelBehavior: FloatingLabelBehavior.never,
                prefixIcon: const Icon(Icons.group),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'تحديث المجموعة',
                  onPressed:
                      isLoading
                          ? null
                          : () =>
                              _fetchGroupUsers(groupNameController.text.trim()),
                ),
              ),
              onSubmitted: (value) {
                _fetchGroupUsers(value.trim());
                _savePreferences();
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.logout),
                    label: const Text('مغادرة'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: isLoading || !inGroup ? null : _handleLeaveGroup,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.login),
                    label: Text(inGroup ? 'تحديث' : 'انضمام'),
                    onPressed: isLoading ? null : _handleJoinGroup,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorSelectionCard() {
    final currentUserName = userNameController.text.trim();
    final bool canSelectColor = currentUserName.isNotEmpty && inGroup;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Theme.of(context).cardColor.withOpacity(0.5),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('اختر اللون'),
            const SizedBox(height: 16),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (groupNameController.text.isEmpty)
              const Center(
                child: Text('انضمم اولا للمجموعة'),
              )
            else
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12.0,
                runSpacing: 12.0,
                children:
                    colorOptions.map((color) {
                      final hexColorString = colorToHexString(color);
                      final takerUserName = _getUserForColor(hexColorString);
                      final isSelectedByMe =
                          selectedColor == hexColorString &&
                          takerUserName == currentUserName;
                      final isTakenByOther =
                          takerUserName != null &&
                          takerUserName != currentUserName;

                      return _ColorSwatchWithName(
                        color: color,
                        userName: takerUserName,
                        isSelected: isSelectedByMe,
                        isTaken: isTakenByOther,
                        onTap:
                            !canSelectColor || isTakenByOther
                                ? null
                                : () => _handleColorSelection(color),
                      );
                    }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

// A widget for the color swatch with the user's name below it.
class _ColorSwatchWithName extends StatelessWidget {
  final Color color;
  final String? userName;
  final bool isSelected;
  final bool isTaken;
  final VoidCallback? onTap;

  const _ColorSwatchWithName({
    required this.color,
    this.userName,
    required this.isSelected,
    required this.isTaken,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isTaken ? 0.5 : 1.0,
      child: Column(
        children: [
          GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border:
                    isSelected
                        ? Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 3.5,
                        )
                        : Border.all(
                          color: Colors.white.withOpacity(0.8),
                          width: 1.5,
                        ),
              ),
              child:
                  isSelected
                      ? Icon(
                        Icons.check,
                        color:
                            color.computeLuminance() > 0.5
                                ? Colors.black
                                : Colors.white,
                      )
                      : null,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 20,
            child: Text(
              userName ?? '',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
