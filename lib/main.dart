import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'services/mesh_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ============================================================
  // FIREBASE
  // ============================================================

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ============================================================
  // SUPABASE
  // ============================================================

  await Supabase.initialize(
    url: 'https://izxxkcepflvtzykefpsn.supabase.co',
    publishableKey:
        'sb_publishable_pVnAWk3j-Kf96x5aeFneAA_znlCSt0w',
  );

  // ============================================================
  // LOCAL NOTIFICATIONS
  // ============================================================

  await NotificationService.instance.initialize();

  // ============================================================
  // START MESH NETWORK
  // ============================================================

  try {
    await MeshService.instance.start();
  } catch (e) {
    debugPrint('MESH AUTO START ERROR: $e');
  }

  // ============================================================
  // LISTEN FOR OFFLINE SOS
  // ============================================================

  MeshService.instance.sosStream.listen(
    (sos) async {
      final String senderName =
          sos['senderName']?.toString() ?? 'Nearby TrekCure user';

      final String payload =
          sos['payload']?.toString() ??
          'Emergency SOS received from a nearby device.';

      debugPrint('================================');
      debugPrint('OFFLINE SOS NOTIFICATION TRIGGERED');
      debugPrint('From: $senderName');
      debugPrint('Payload: $payload');
      debugPrint('================================');

      await NotificationService.instance.showNotification(
        title: '🚨 EMERGENCY SOS',
        body: '$senderName needs help nearby!',
      );
    },
  );

  // ============================================================
  // START APP
  // ============================================================

  runApp(const TrekCureApp());
}

// ==================================================================
// TREKCURE APP
// ==================================================================

class TrekCureApp extends StatelessWidget {
  const TrekCureApp({super.key});

  @override
  Widget build(
    BuildContext context,
  ) {
    return MaterialApp(
      title: 'TrekCure',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const SplashScreen(),
    );
  }
} 