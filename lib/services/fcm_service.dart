import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> initializeFcm() async {
  try {
    debugPrint('========== FCM INITIALIZATION STARTED ==========');

    final messaging = FirebaseMessaging.instance;

    debugPrint('Requesting notification permission...');

    final settings = await messaging.requestPermission();

    debugPrint(
      'Notification permission: ${settings.authorizationStatus}',
    );

    debugPrint('Getting FCM token...');

    final fcmToken = await messaging.getToken();

    debugPrint('FCM TOKEN: $fcmToken');

    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      debugPrint('No logged-in user. Token not saved yet.');
      return;
    }

    if (fcmToken != null) {
      await Supabase.instance.client
          .from('profiles')
          .update({'fcm_token': fcmToken})
          .eq('id', user.id);

      debugPrint('FCM token saved to Supabase');
    }
  } catch (e, stackTrace) {
    debugPrint('FCM ERROR: $e');
    debugPrintStack(stackTrace: stackTrace);
  }
}