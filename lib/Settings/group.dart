// Flutter imports
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Local imports
import 'package:crosswords/Settings/firebase_service.dart';
import 'package:crosswords/Utilities/color_utils.dart';

// ========== Simplified Group Settings Page ========== //

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

    // Auto-load group if user was already in one
    if (inGroup && groupNameController.text.isNotEmpty) {
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

  // Simplified join/create group method
  Future<void> _handleJoinOrCreateGroup() async {
    final groupName = groupNameController.text.trim();
    final userName = userNameController.text.trim();
    
    if (groupName.isEmpty || userName.isEmpty) {
      _showSnackBar('يرجى إدخال اسم المستخدم واسم المجموعة');
      return;
    }

    setState(() => isLoading = true);
    
    // First, try to join with current selected color
    bool success = await _firebaseService.joinGroup(
      groupName,
      userName,
      selectedColor,
    );

    // If color is taken, try to find an available color automatically
    if (!success) {
      await _fetchGroupUsers(groupName);
      String? availableColor = _findAvailableColor();
      
      if (availableColor != null) {
        success = await _firebaseService.joinGroup(
          groupName,
          userName,
          availableColor,
        );
        if (success) {
          selectedColor = availableColor;
        }
      }
    }

    if (success) {
      if (!mounted) return;
      setState(() => inGroup = true);
      await _savePreferences();
      await _fetchGroupUsers(groupName);
      _showSnackBar('تم الانضمام للمجموعة بنجاح!');
    } else {
      _showSnackBar('جميع الألوان محجوزة في هذه المجموعة');
    }
    
    if (mounted) setState(() => isLoading = false);
  }

  String? _findAvailableColor() {
    for (final color in colorOptions) {
      final colorHex = colorToHexString(color);
      if (_getUserForColor(colorHex) == null) {
        return colorHex;
      }
    }
    return null;
  }

  Future<void> _handleLeaveGroup() async {
    final groupName = groupNameController.text.trim();
    final userName = userNameController.text.trim();
    if (groupName.isEmpty || userName.isEmpty) return;

    // Show confirmation dialog
    final shouldLeave = await _showLeaveDialog();
    if (!shouldLeave) return;

    setState(() => isLoading = true);
    final success = await _firebaseService.leaveGroup(groupName, userName);
    
    if (success) {
      if (!mounted) return;
      setState(() {
        inGroup = false;
        groupUsers.clear();
      });
      groupNameController.clear();
      await _savePreferences();
      _showSnackBar('تم مغادرة المجموعة');
    } else {
      _showSnackBar('فشل في مغادرة المجموعة');
    }
    
    if (mounted) setState(() => isLoading = false);
  }

  Future<bool> _showLeaveDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مغادرة المجموعة'),
        content: const Text('هل أنت متأكد من مغادرة المجموعة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('مغادرة'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _handleColorSelection(Color color) async {
    if (!inGroup) {
      _showSnackBar('يجب الانضمام للمجموعة أولاً');
      return;
    }

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
      _showSnackBar('تم تغيير اللون بنجاح');
    } else {
      _showSnackBar('هذا اللون محجوز من قبل مستخدم آخر');
      await _fetchGroupUsers(groupName);
    }

    if (mounted) setState(() => isLoading = false);
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                if (!inGroup) ...[
                  _buildJoinGroupCard(),
                  const SizedBox(height: 16),
                  _buildHelpCard(),
                ] else ...[
                  _buildCurrentGroupCard(),
                  const SizedBox(height: 16),
                  _buildColorSelectionCard(),
                  const SizedBox(height: 16),
                  _buildMembersCard(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===== Widget Builders =====

  Widget _buildJoinGroupCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.group_add, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'انضم إلى مجموعة',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: userNameController,
              decoration: InputDecoration(
                labelText: 'اسمك',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: groupNameController,
              decoration: InputDecoration(
                labelText: 'اسم المجموعة',
                prefixIcon: const Icon(Icons.group),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                helperText: 'اكتب اسم مجموعة موجودة أو إنشاء جديدة',
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isLoading ? null : _handleJoinOrCreateGroup,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'انضم أو أنشئ مجموعة',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpCard() {
    return Card(
      elevation: 1,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'كيف يعمل؟',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '• اكتب اسمك واسم المجموعة\n'
              '• إذا كانت المجموعة موجودة، ستنضم إليها\n'
              '• إذا لم تكن موجودة، ستنشأ مجموعة جديدة\n'
              '• سيتم اختيار لون متاح لك تلقائياً',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentGroupCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.group, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'مجموعة: ${groupNameController.text}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'المستخدم: ${userNameController.text}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hexStringToColor(selectedColor),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isLoading ? null : _handleLeaveGroup,
                icon: const Icon(Icons.exit_to_app),
                label: const Text('مغادرة المجموعة'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  side: BorderSide(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorSelectionCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.palette, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'اختر لونك',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 16.0,
                runSpacing: 16.0,
                children: colorOptions.map((color) {
                  final hexColorString = colorToHexString(color);
                  final takerUserName = _getUserForColor(hexColorString);
                  final isSelectedByMe = selectedColor == hexColorString;
                  final isTakenByOther = takerUserName != null && takerUserName != userNameController.text.trim();

                  return GestureDetector(
                    onTap: isTakenByOther ? null : () => _handleColorSelection(color),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                        border: Border.all(
                          color: isSelectedByMe 
                              ? Theme.of(context).colorScheme.primary
                              : Colors.white.withValues(alpha: 0.8),
                          width: isSelectedByMe ? 4 : 2,
                        ),
                        boxShadow: [
                          if (isSelectedByMe)
                            BoxShadow(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          if (isSelectedByMe)
                            Center(
                              child: Icon(
                                Icons.check,
                                color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                                size: 24,
                              ),
                            ),
                          if (isTakenByOther)
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withValues(alpha: 0.5),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.lock,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersCard() {
    if (groupUsers.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'أعضاء المجموعة (${groupUsers.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...groupUsers.entries.map((entry) {
              final userName = entry.key;
              final userColor = hexStringToColor(entry.value);
              final isCurrentUser = userName == userNameController.text.trim();

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isCurrentUser 
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: userColor,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        userName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (isCurrentUser)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'أنت',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}