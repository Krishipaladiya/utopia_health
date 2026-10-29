import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart';

/// Firebase settings for push. Copy the values from Firebase console ->
/// Project settings -> Your apps -> the iOS app (and the GoogleService-Info.plist).
/// While apiKey is empty, push stays off and the app works without Firebase.
class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static FirebaseOptions? get currentPlatform {
    final options = defaultTargetPlatform == TargetPlatform.iOS ? ios : android;
    return options.apiKey.isEmpty ? null : options;
  }

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDX9IKQuFG1hWirITFSOwy-E7QQmKgeOtE', // API_KEY
    appId: '1:639999165621:ios:47476e4c17db428decaafc', // GOOGLE_APP_ID
    messagingSenderId: '639999165621', // GCM_SENDER_ID
    projectId: 'utopia-health', // PROJECT_ID
    storageBucket: 'utopia-health.firebasestorage.app', // STORAGE_BUCKET
    iosBundleId: 'com.utopia.utopiaHealth',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: '',
    appId: '',
    messagingSenderId: '',
    projectId: '',
    storageBucket: '',
  );
}
