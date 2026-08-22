import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Supabase.initialize(
    url: 'https://izxxkcepflvtzykefpsn.supabase.co',
    publishableKey: 'sb_publishable_pVnAWk3j-Kf96x5aeFneAA_znlCSt0w',
  );

  runApp(const TrekCureApp());
}

class TrekCureApp extends StatelessWidget {
  const TrekCureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TrekCure',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const SplashScreen(),
    );
  }
}
