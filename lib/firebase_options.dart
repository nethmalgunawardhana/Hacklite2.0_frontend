import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
        return linux;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'YOUR_API_KEY',
    appId: '1:YOUR_PROJECT_NUMBER:web:YOUR_WEB_APP_ID',
    messagingSenderId: 'YOUR_PROJECT_NUMBER',
    projectId: 'your-project-id',
    authDomain: 'your-project-id.firebaseapp.com',
    storageBucket: 'your-project-id.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_API_KEY',
    appId: '1:YOUR_PROJECT_NUMBER:android:YOUR_ANDROID_APP_ID',
    messagingSenderId: 'YOUR_PROJECT_NUMBER',
    projectId: 'your-project-id',
    storageBucket: 'your-project-id.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_API_KEY',
    appId: '1:YOUR_PROJECT_NUMBER:ios:YOUR_IOS_APP_ID',
    messagingSenderId: 'YOUR_PROJECT_NUMBER',
    projectId: 'your-project-id',
    storageBucket: 'your-project-id.appspot.com',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'YOUR_API_KEY',
    appId: '1:YOUR_PROJECT_NUMBER:macos:YOUR_MACOS_APP_ID',
    messagingSenderId: 'YOUR_PROJECT_NUMBER',
    projectId: 'your-project-id',
    storageBucket: 'your-project-id.appspot.com',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'YOUR_API_KEY',
    appId: '1:YOUR_PROJECT_NUMBER:windows:YOUR_WINDOWS_APP_ID',
    messagingSenderId: 'YOUR_PROJECT_NUMBER',
    projectId: 'your-project-id',
    storageBucket: 'your-project-id.appspot.com',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'YOUR_API_KEY',
    appId: '1:YOUR_PROJECT_NUMBER:linux:YOUR_LINUX_APP_ID',
    messagingSenderId: 'YOUR_PROJECT_NUMBER',
    projectId: 'your-project-id',
    storageBucket: 'your-project-id.appspot.com',
  );
}
