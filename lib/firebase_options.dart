// File generated for Chessical Firebase configuration.
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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
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

  static const String _webApiKey = String.fromEnvironment(
    'FIREBASE_WEB_API_KEY',
    defaultValue: 'AIzaSy_WEB_KEY_PLACEHOLDER',
  );
  static const String _androidApiKey = String.fromEnvironment(
    'FIREBASE_ANDROID_API_KEY',
    defaultValue: 'AIzaSy_ANDROID_KEY_PLACEHOLDER',
  );
  static const String _iosApiKey = String.fromEnvironment(
    'FIREBASE_IOS_API_KEY',
    defaultValue: 'AIzaSy_IOS_KEY_PLACEHOLDER',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: _webApiKey,
    appId: '1:84280519183:web:a4a9f83b8ef090b23f117a',
    messagingSenderId: '84280519183',
    projectId: 'chessical1',
    authDomain: 'chessical1.firebaseapp.com',
    storageBucket: 'chessical1.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: _androidApiKey,
    appId: '1:84280519183:android:a4a9f83b8ef090b23f117a',
    messagingSenderId: '84280519183',
    projectId: 'chessical1',
    storageBucket: 'chessical1.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: _iosApiKey,
    appId: '1:84280519183:ios:648ff6f0428f24743f117a',
    messagingSenderId: '84280519183',
    projectId: 'chessical1',
    storageBucket: 'chessical1.firebasestorage.app',
    iosBundleId: 'com.hw.chessical',
  );
}
