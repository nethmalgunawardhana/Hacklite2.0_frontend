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
    apiKey: 'AIzaSyDmlUKgAnMmGe51K18V1FEpX37UY0ZdFrk',
    appId: '1:940330317059:web:a1b2c3d4e5f6g7h8i9j0',
    messagingSenderId: '940330317059',
    projectId: 'hacklite-9c06e',
    authDomain: 'hacklite-9c06e.firebaseapp.com',
    storageBucket: 'hacklite-9c06e.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDmlUKgAnMmGe51K18V1FEpX37UY0ZdFrk',
    appId: '1:940330317059:android:1cf71dfe6af37dd2052536',
    messagingSenderId: '940330317059',
    projectId: 'hacklite-9c06e',
    storageBucket: 'hacklite-9c06e.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDmlUKgAnMmGe51K18V1FEpX37UY0ZdFrk',
    appId: '1:940330317059:ios:a1b2c3d4e5f6g7h8i9j0',
    messagingSenderId: '940330317059',
    projectId: 'hacklite-9c06e',
    storageBucket: 'hacklite-9c06e.firebasestorage.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDmlUKgAnMmGe51K18V1FEpX37UY0ZdFrk',
    appId: '1:940330317059:macos:a1b2c3d4e5f6g7h8i9j0',
    messagingSenderId: '940330317059',
    projectId: 'hacklite-9c06e',
    storageBucket: 'hacklite-9c06e.firebasestorage.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDmlUKgAnMmGe51K18V1FEpX37UY0ZdFrk',
    appId: '1:940330317059:windows:a1b2c3d4e5f6g7h8i9j0',
    messagingSenderId: '940330317059',
    projectId: 'hacklite-9c06e',
    storageBucket: 'hacklite-9c06e.firebasestorage.app',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'AIzaSyDmlUKgAnMmGe51K18V1FEpX37UY0ZdFrk',
    appId: '1:940330317059:linux:a1b2c3d4e5f6g7h8i9j0',
    messagingSenderId: '940330317059',
    projectId: 'hacklite-9c06e',
    storageBucket: 'hacklite-9c06e.firebasestorage.app',
  );
}
