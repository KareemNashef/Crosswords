// Flutter imports
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Local imports
import 'package:crosswords/providors.dart';

// A list of available accent colors
const List<Color> _accentColors = [
  Color(0xFFEF5350), // Red
  Color(0xFF66BB6A), // Green
  Color(0xFF42A5F5), // Blue
  Color(0xFFFFCA28), // Yellow (adjusted for better visibility)
  Color(0xFFAB47BC), // Purple
  Color(0xFFFF7043), // Orange
  Color(0xFF26C6DA), // Teal
  Color(0xFF7E57C2), // Deep Purple
];

// Theme settings page
class ThemeSettingsPage extends StatelessWidget {
  const ThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Container(
      // Consistent gradient background
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
            'اعدادات المظهر',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Theme Mode Section
              _buildSectionTitle(context, 'اعدادات اللون'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _ThemeSelectionCard(
                    label: 'فاتح',
                    assetPath: 'assets/settings/LightMode.png',
                    isSelected: themeProvider.themeMode == ThemeMode.light,
                    onTap:
                        () => context.read<ThemeProvider>().setThemeMode(
                          ThemeMode.light,
                        ),
                  ),
                  _ThemeSelectionCard(
                    label: 'غامق',
                    assetPath: 'assets/settings/DarkMode.png',
                    isSelected: themeProvider.themeMode == ThemeMode.dark,
                    onTap:
                        () => context.read<ThemeProvider>().setThemeMode(
                          ThemeMode.dark,
                        ),
                  ),
                  _ThemeSelectionCard(
                    label: 'الشسمو',
                    assetPath: 'assets/settings/AutoMode.png',
                    isSelected: themeProvider.themeMode == ThemeMode.system,
                    onTap:
                        () => context.read<ThemeProvider>().setThemeMode(
                          ThemeMode.system,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Accent Color Section
              Card(
                color: Theme.of(context).cardColor.withOpacity(0.5),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 16.0,
                    runSpacing: 16.0,
                    children:
                        _accentColors.map((color) {
                          return _ColorSwatch(
                            color: color,
                            isSelected: themeProvider.mainColor == color,
                            onTap:
                                () => context
                                    .read<ThemeProvider>()
                                    .setMainColor(color),
                          );
                        }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// Widget for the theme selection card (Light/Dark/System)
class _ThemeSelectionCard extends StatelessWidget {
  final String label;
  final String assetPath;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeSelectionCard({
    required this.label,
    required this.assetPath,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? theme.colorScheme.primary.withOpacity(0.2)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              width: 3,
              color:
                  isSelected ? theme.colorScheme.primary : Colors.transparent,
            ),
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(assetPath, fit: BoxFit.cover),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Widget for the circular color swatch
class _ColorSwatch extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorSwatch({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color:
                isSelected
                    ? Theme.of(context).colorScheme.onSurface
                    : Colors.white.withOpacity(0.5),
            width: isSelected ? 3.0 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child:
            isSelected
                ? Center(
                  child: Icon(
                    Icons.check,
                    color: Colors.white,
                  ),
                )
                : null,
      ),
    );
  }
}
