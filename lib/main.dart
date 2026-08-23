import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/reset_password_screen.dart';
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

  debugPrint('FIREBASE INITIALIZED');

  // ============================================================
  // SUPABASE
  // ============================================================

  await Supabase.initialize(
    url: 'https://izxxkcepflvtzykefpsn.supabase.co',
    publishableKey:
        'sb_publishable_pVnAWk3j-Kf96x5aeFneAA_znlCSt0w',
  );

  debugPrint('SUPABASE INITIALIZED');

  // ============================================================
  // LOCAL NOTIFICATIONS
  // ============================================================

  await NotificationService.instance.initialize();

  debugPrint('NOTIFICATIONS INITIALIZED');

  // ============================================================
  // START MESH NETWORK
  // ============================================================

  try {
    await MeshService.instance.start();

    debugPrint('MESH NETWORK STARTED');
  } catch (e) {
    debugPrint(
      'MESH AUTO START ERROR: $e',
    );
  }

  // ============================================================
  // OFFLINE SOS + SOS CANCELLATION NOTIFICATIONS
  // ============================================================

  MeshService.instance.sosStream.listen(
    (sos) async {
      try {
        final String type =
            sos['type']?.toString().toLowerCase() ?? 'sos';

        final String senderName =
            sos['senderName']?.toString() ??
                'Nearby TrekCure user';

        final String sosId =
            sos['sosId']?.toString() ?? '';

        final String location =
            sos['location']?.toString() ??
                'Location unavailable';

        final String payload =
            sos['payload']?.toString() ?? '';

        // Same notification ID is used for SOS and cancellation.
        final int notificationId =
            sosId.isNotEmpty
                ? sosId.hashCode.abs()
                : senderName.hashCode.abs();

        debugPrint('================================');
        debugPrint('OFFLINE SOS EVENT RECEIVED');
        debugPrint('Type: $type');
        debugPrint('SOS ID: $sosId');
        debugPrint('From: $senderName');
        debugPrint('Location: $location');
        debugPrint('Payload: $payload');
        debugPrint('================================');

        // ========================================================
        // SOS CANCELLED
        // ========================================================

        if (type == 'cancelled') {
          await NotificationService.instance.showNotification(
            id: notificationId,
            title: '✅ SOS CANCELLED',
            body:
                '$senderName has cancelled the SOS.',
          );

          debugPrint(
            'SOS CANCELLATION NOTIFICATION SHOWN',
          );

          return;
        }

        // ========================================================
        // NORMAL SOS
        // ========================================================

        await NotificationService.instance.showNotification(
          id: notificationId,
          title: '🚨 EMERGENCY SOS',
          body:
              '$senderName needs help nearby!',
        );

        debugPrint(
          'SOS EMERGENCY NOTIFICATION SHOWN',
        );
      } catch (e) {
        debugPrint(
          'SOS NOTIFICATION ERROR: $e',
        );
      }
    },
    onError: (error) {
      debugPrint(
        'SOS STREAM ERROR: $error',
      );
    },
  );

  // ============================================================
  // START APP
  // ============================================================

  runApp(
    const TrekCureApp(),
  );
}

// ==================================================================
// TREKCURE APP
// ==================================================================

class TrekCureApp extends StatefulWidget {
  const TrekCureApp({
    super.key,
  });

  @override
  State<TrekCureApp> createState() =>
      _TrekCureAppState();
}

class _TrekCureAppState
    extends State<TrekCureApp> {

  // ============================================================
  // SUPABASE AUTH LISTENER
  // ============================================================

  StreamSubscription<AuthState>?
      _authSubscription;

  // ============================================================
  // RESET SCREEN PROTECTION
  // ============================================================

  bool _openingResetScreen = false;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _listenForAuthChanges();
  }

  // ============================================================
  // SUPABASE AUTH STATE LISTENER
  // ============================================================

  void _listenForAuthChanges() {
    debugPrint(
      '================================',
    );

    debugPrint(
      'STARTING SUPABASE AUTH LISTENER',
    );

    debugPrint(
      '================================',
    );

    _authSubscription =
        Supabase
            .instance
            .client
            .auth
            .onAuthStateChange
            .listen(
      (AuthState state) {
        debugPrint(
          '================================',
        );

        debugPrint(
          'SUPABASE AUTH EVENT: ${state.event}',
        );

        debugPrint(
          'SESSION EXISTS: ${state.session != null}',
        );

        if (state.session != null) {
          debugPrint(
            'USER ID: ${state.session!.user.id}',
          );
        }

        debugPrint(
          '================================',
        );

        // ========================================================
        // PASSWORD RECOVERY
        // ========================================================

        if (state.event ==
            AuthChangeEvent.passwordRecovery) {
          debugPrint(
            '================================',
          );

          debugPrint(
            'PASSWORD RECOVERY EVENT RECEIVED',
          );

          debugPrint(
            'OPENING RESET PASSWORD SCREEN',
          );

          debugPrint(
            '================================',
          );

          _openResetPassword();
        }
      },
      onError: (Object error) {
        debugPrint(
          'SUPABASE AUTH LISTENER ERROR: $error',
        );
      },
    );
  }

  // ============================================================
  // OPEN RESET PASSWORD SCREEN
  // ============================================================

  void _openResetPassword() {
    // ----------------------------------------------------------
    // PREVENT DUPLICATE RESET SCREENS
    // ----------------------------------------------------------

    if (_openingResetScreen) {
      debugPrint(
        'RESET PASSWORD SCREEN ALREADY OPEN',
      );

      return;
    }

    if (!mounted) {
      debugPrint(
        'RESET PASSWORD SCREEN CANNOT OPEN: APP NOT MOUNTED',
      );

      return;
    }

    _openingResetScreen = true;

    debugPrint(
      'PREPARING RESET PASSWORD SCREEN',
    );

    // ----------------------------------------------------------
    // WAIT UNTIL FLUTTER FRAME IS READY
    // ----------------------------------------------------------

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (!mounted) {
          _openingResetScreen = false;

          return;
        }

        debugPrint(
          'NAVIGATING TO RESET PASSWORD SCREEN',
        );

        Navigator.of(context)
            .push(
          MaterialPageRoute(
            builder: (context) =>
                const ResetPasswordScreen(),
          ),
        )
            .then(
          (_) {
            _openingResetScreen = false;

            debugPrint(
              'RESET PASSWORD SCREEN CLOSED',
            );
          },
        );
      },
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _authSubscription?.cancel();

    super.dispose();
  }

  // ============================================================
  // APP UI
  // ============================================================

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