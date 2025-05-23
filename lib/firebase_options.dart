// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDszxpLUrzQ3NrtX5Ntxe6TauJnkiSaU7k',
    appId: '1:918058744405:web:53681e73f903983f8072dc',
    messagingSenderId: '918058744405',
    projectId: 'crosswords-c53ab',
    authDomain: 'crosswords-c53ab.firebaseapp.com',
    storageBucket: 'crosswords-c53ab.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDzXHQQV2WXuLLCsoQ6QxlTqoQ6h1us3IE',
    appId: '1:918058744405:android:bed671d121dc90728072dc',
    messagingSenderId: '918058744405',
    projectId: 'crosswords-c53ab',
    storageBucket: 'crosswords-c53ab.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD50HSRY0ZUmCuoMSaTvGq2v3rNlq0OF08',
    appId: '1:918058744405:ios:26685171341425a38072dc',
    messagingSenderId: '918058744405',
    projectId: 'crosswords-c53ab',
    storageBucket: 'crosswords-c53ab.firebasestorage.app',
    iosBundleId: 'com.nunya.crosswords',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyD50HSRY0ZUmCuoMSaTvGq2v3rNlq0OF08',
    appId: '1:918058744405:ios:66302710bac3cbf98072dc',
    messagingSenderId: '918058744405',
    projectId: 'crosswords-c53ab',
    storageBucket: 'crosswords-c53ab.firebasestorage.app',
    iosBundleId: 'com.example.crosswords',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDszxpLUrzQ3NrtX5Ntxe6TauJnkiSaU7k',
    appId: '1:918058744405:web:08f77892f196b2948072dc',
    messagingSenderId: '918058744405',
    projectId: 'crosswords-c53ab',
    authDomain: 'crosswords-c53ab.firebaseapp.com',
    storageBucket: 'crosswords-c53ab.firebasestorage.app',
  );
}
