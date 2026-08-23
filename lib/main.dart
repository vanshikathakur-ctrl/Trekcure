import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';

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

  // ============================================================
  // START MESH NETWORK
  // ============================================================

  try {
    await MeshService.instance.start();
  } catch (e) {
    debugPrint('MESH AUTO START ERROR: $e');
  }

  // ============================================================
  // OFFLINE SOS
  // ============================================================

  MeshService.instance.sosStream.listen(
    (sos) async {
      final String senderName =
          sos['senderName']?.toString() ??
              'Nearby TrekCure user';

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

class TrekCureApp extends StatefulWidget {
  const TrekCureApp({super.key});

  @override
  State<TrekCureApp> createState() =>
      _TrekCureAppState();
}

class _TrekCureAppState
    extends State<TrekCureApp> {
  // ============================================================
  // DEEP LINK SERVICE
  // ============================================================

  final AppLinks _appLinks = AppLinks();

  StreamSubscription<Uri>? _deepLinkSubscription;

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

    _initializeDeepLinks();
  }

  // ============================================================
  // SUPABASE AUTH LISTENER
  // ============================================================

  void _listenForAuthChanges() {
    debugPrint('STARTING SUPABASE AUTH LISTENER');

    Supabase
        .instance
        .client
        .auth
        .onAuthStateChange
        .listen(
      (AuthState state) {
        debugPrint('================================');
        debugPrint(
          'SUPABASE AUTH EVENT: ${state.event}',
        );
        debugPrint(
          'SESSION EXISTS: ${state.session != null}',
        );
        debugPrint('================================');

        // --------------------------------------------------------
        // PASSWORD RECOVERY
        // --------------------------------------------------------

        if (state.event ==
            AuthChangeEvent.passwordRecovery) {
          debugPrint(
            'PASSWORD RECOVERY EVENT RECEIVED',
          );

          _openResetPassword();
        }
      },
      onError: (error) {
        debugPrint(
          'AUTH LISTENER ERROR: $error',
        );
      },
    );
  }

  // ============================================================
  // INITIALIZE DEEP LINKS
  // ============================================================

  Future<void> _initializeDeepLinks() async {
    debugPrint('================================');
    debugPrint('TREKCURE DEEP LINK SERVICE STARTED');
    debugPrint('================================');

    // ----------------------------------------------------------
    // APP ALREADY OPEN / BACKGROUND
    // ----------------------------------------------------------

    _deepLinkSubscription =
        _appLinks.uriLinkStream.listen(
      (Uri uri) {
        debugPrint('================================');
        debugPrint('INCOMING DEEP LINK');
        debugPrint('URI: $uri');
        debugPrint('SCHEME: ${uri.scheme}');
        debugPrint('HOST: ${uri.host}');
        debugPrint('PATH: ${uri.path}');
        debugPrint('QUERY: ${uri.query}');
        debugPrint('FRAGMENT: ${uri.fragment}');
        debugPrint('================================');

        _handleDeepLink(uri);
      },
      onError: (Object error) {
        debugPrint(
          'DEEP LINK STREAM ERROR: $error',
        );
      },
    );

    // ----------------------------------------------------------
    // APP WAS CLOSED
    // ----------------------------------------------------------

    try {
      final Uri? initialUri =
          await _appLinks.getInitialLink();

      if (initialUri != null) {
        debugPrint('================================');
        debugPrint('INITIAL DEEP LINK RECEIVED');
        debugPrint('URI: $initialUri');
        debugPrint('SCHEME: ${initialUri.scheme}');
        debugPrint('HOST: ${initialUri.host}');
        debugPrint('PATH: ${initialUri.path}');
        debugPrint('QUERY: ${initialUri.query}');
        debugPrint(
          'FRAGMENT: ${initialUri.fragment}',
        );
        debugPrint('================================');

        _handleDeepLink(initialUri);
      } else {
        debugPrint(
          'NO INITIAL DEEP LINK',
        );
      }
    } catch (e) {
      debugPrint(
        'INITIAL DEEP LINK ERROR: $e',
      );
    }
  }

  // ============================================================
  // HANDLE DEEP LINK
  // ============================================================

  void _handleDeepLink(Uri uri) {
    debugPrint('========================================');
    debugPrint('TREKCURE DEEP LINK RECEIVED');
    debugPrint('URI: $uri');
    debugPrint('SCHEME: ${uri.scheme}');
    debugPrint('HOST: ${uri.host}');
    debugPrint('PATH: ${uri.path}');
    debugPrint('QUERY: ${uri.query}');
    debugPrint('FRAGMENT: ${uri.fragment}');
    debugPrint('========================================');

    // ----------------------------------------------------------
    // CHECK SCHEME
    // ----------------------------------------------------------

    if (uri.scheme != 'io.supabase.trekcure') {
      debugPrint(
        'DEEP LINK IGNORED: WRONG SCHEME',
      );
      return;
    }

    // ----------------------------------------------------------
    // CHECK HOST
    // ----------------------------------------------------------

    if (uri.host != 'reset-password') {
      debugPrint(
        'DEEP LINK IGNORED: WRONG HOST',
      );
      return;
    }

    debugPrint(
      'RESET PASSWORD DEEP LINK CONFIRMED',
    );

    // ----------------------------------------------------------
    // IMPORTANT
    //
    // Supabase should process the recovery session and emit
    // AuthChangeEvent.passwordRecovery.
    //
    // The auth listener above will open ResetPasswordScreen.
    // We also open it here as a fallback for the deep-link case.
    // ----------------------------------------------------------

    _openResetPassword();
  }

  // ============================================================
  // OPEN RESET PASSWORD SCREEN
  // ============================================================

  void _openResetPassword() {
    if (_openingResetScreen) {
      debugPrint(
        'RESET SCREEN ALREADY OPENING',
      );
      return;
    }

    _openingResetScreen = true;

    debugPrint(
      'OPENING RESET PASSWORD SCREEN',
    );

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (!mounted) {
          _openingResetScreen = false;
          return;
        }

        Navigator.of(context)
            .push(
          MaterialPageRoute(
            builder: (_) =>
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
    _deepLinkSubscription?.cancel();

    super.dispose();
  }

  // ============================================================
  // APP UI
  // ============================================================

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