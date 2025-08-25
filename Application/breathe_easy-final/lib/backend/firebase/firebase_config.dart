import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

Future initFirebase() async {
  if (kIsWeb) {
    await Firebase.initializeApp(
        options: const FirebaseOptions(
            apiKey: "AIzaSyCzkWsQBWQJM8y3tBnuICPgJLeDoqBL1qI",
            authDomain: "breatheeasy-482fb.firebaseapp.com",
            projectId: "breatheeasy-482fb",
            storageBucket: "breatheeasy-482fb.appspot.com",
            messagingSenderId: "785170886847",
            appId: "1:785170886847:web:7281e8c23cddab7d49560a",
            measurementId: "G-8HXC4WBP2H"));
  } else {
    await Firebase.initializeApp();
  }
}
