// Flutter imports
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Local imports
import 'package:crosswords/providors.dart';

// Theme settings page
class ThemeSettingsPage extends StatelessWidget {
  const ThemeSettingsPage({super.key});

  // App theme selection bar
  Widget themeSelectionBar(BuildContext context) {
    double size = 120;
    double sizePic = 200;

    Widget themeCard({
      required String assetPath,
      required bool isSelected,
      required VoidCallback onTap,
    }) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: size,
        height: sizePic,
        decoration: BoxDecoration(
          color:
              isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            width: 3,
            color:
                isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  Container(
                    width: sizePic,
                    height: sizePic,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  Image.asset(
                    assetPath,
                    width: sizePic,
                    height: sizePic,
                    fit: BoxFit.cover,
                  ),
                ],
              ),
            ),

            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onTap,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        themeCard(
          assetPath: 'assets/settings/LightMode.png',
          isSelected:
              context.watch<ThemeProvider>().themeMode == ThemeMode.light,
          onTap:
              () => context.read<ThemeProvider>().setThemeMode(ThemeMode.light),
        ),
        themeCard(
          assetPath: 'assets/settings/DarkMode.png',
          isSelected:
              context.watch<ThemeProvider>().themeMode == ThemeMode.dark,
          onTap:
              () => context.read<ThemeProvider>().setThemeMode(ThemeMode.dark),
        ),
        themeCard(
          assetPath: 'assets/settings/AutoMode.png',
          isSelected:
              context.watch<ThemeProvider>().themeMode == ThemeMode.system,
          onTap:
              () =>
                  context.read<ThemeProvider>().setThemeMode(ThemeMode.system),
        ),
      ],
    );
  }

  // App color selection bar
  Widget colorSelectionBar(context) {
    Widget colorButton(BuildContext context, Color color) {
      return OutlinedButton(
        style: OutlinedButton.styleFrom(
          fixedSize: const Size(350, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: color,
          side: BorderSide(
            color:
                context.watch<ThemeProvider>().mainColor == color
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
            width: 6,
          ),
        ),
        onPressed: () {
          context.read<ThemeProvider>().setMainColor(
            color,
          ); // Use context.read to update the color
        },
        child: const SizedBox.shrink(),
      );
    }

    return Column(
      children: [
        colorButton(context, Color(0xFFEF5350)),
        SizedBox(height: 16),
        colorButton(context, Color(0xFF66BB6A)),
        SizedBox(height: 16),
        colorButton(context, Color(0xFF42A5F5)),
        SizedBox(height: 16),
        colorButton(context, Color(0xFFFFEB3B)),
        SizedBox(height: 16),
        colorButton(context, Color(0xFFAB47BC)),
        SizedBox(height: 16),
        colorButton(context, Color(0xFFFF7043)),
        SizedBox(height: 16),
        colorButton(context, Color(0xFF26C6DA)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text("Theme"),
            Spacer(),
            Icon(
              Icons.format_paint,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            themeSelectionBar(context),
            SizedBox(height: 16),

            // Title
            Text(
              "Accent color",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),

            SizedBox(height: 16),

            colorSelectionBar(context),
          ],
        ),
      ),
    );
  }
}
