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

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDwmJ5E7GNMN73eCH0OcV7eguJSqOBLumE',
    appId: '1:84280519183:web:a4a9f83b8ef090b23f117a',
    messagingSenderId: '84280519183',
    projectId: 'chessical1',
    authDomain: 'chessical1.firebaseapp.com',
    storageBucket: 'chessical1.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDwmJ5E7GNMN73eCH0OcV7eguJSqOBLumE',
    appId: '1:84280519183:android:a4a9f83b8ef090b23f117a',
    messagingSenderId: '84280519183',
    projectId: 'chessical1',
    storageBucket: 'chessical1.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDwmJ5E7GNMN73eCH0OcV7eguJSqOBLumE',
    appId: '1:84280519183:ios:a4a9f83b8ef090b23f117a',
    messagingSenderId: '84280519183',
    projectId: 'chessical1',
    storageBucket: 'chessical1.firebasestorage.app',
    iosBundleId: 'com.hw.chessical',
  );
}
