// Flutter imports
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';

// Local imports
import 'package:crosswords/main_page.dart';
import 'package:crosswords/providors.dart';

void main() async {

  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

Firebase.initializeApp().then((value) {
}).catchError((error) {
});

  final themeProvider = ThemeProvider();
  await themeProvider.loadFromPrefs();

  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
      ],
      child: MainApp(),
    ),
  );
}


// ========== Main app ========== //

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  @override
  Widget build(BuildContext context) {

    // Get theme provider
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(

      // Define light theme
      theme: ThemeData.from(
        colorScheme: ColorScheme.fromSeed(
          seedColor: themeProvider.mainColor,
          brightness: Brightness.light,
        ),
      ),

      // Define dark theme
      darkTheme: ThemeData.from(
        colorScheme: ColorScheme.fromSeed(
          seedColor: themeProvider.mainColor,
          brightness: Brightness.dark,
        ),
      ),

      // Set theme mode
      themeMode: themeProvider.themeMode,

      locale: const Locale('ar'), // Optionally set the default startup locale to Arabic
      supportedLocales: const [
        Locale('en', ''), // English, no country code
        Locale('ar', ''), // Arabic, no country code
        // ... any other locales you support
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        // ... add your app-specific localization delegates if you have them
      ],
      
      // Set initial route
      home: Scaffold(body: MainPage()),
    );
  }
}
