import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class LiveFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('Unsupported platform for live flavor');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBMkrxqgbO6cCW8h_L-D3I5HRysV1DvoJY',
    appId: '1:43518990471:android:750efa2a89467fcfdf0022',
    messagingSenderId: '43518990471',
    projectId: 'runmate-live',
    authDomain: 'runmate-live.firebaseapp.com',
    databaseURL: 'https://runmate-live-default-rtdb.firebaseio.com',
    storageBucket: 'runmate-live.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBMkrxqgbO6cCW8h_L-D3I5HRysV1DvoJY',
    appId: '1:43518990471:android:750efa2a89467fcfdf0022',
    messagingSenderId: '43518990471',
    projectId: 'runmate-live',
    databaseURL: 'https://runmate-live-default-rtdb.firebaseio.com',
    storageBucket: 'runmate-live.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA9JIXFrWMKiVIhZluA13DT9hNEoU1Kb5g',
    appId: '1:43518990471:ios:c5e629e84474a7eddf0022',
    messagingSenderId: '43518990471',
    projectId: 'runmate-live',
    databaseURL: 'https://runmate-live-default-rtdb.firebaseio.com',
    storageBucket: 'runmate-live.firebasestorage.app',
    iosBundleId: 'com.xor.runmate',
  );
}
