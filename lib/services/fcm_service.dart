import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> initializeFcm() async {
  final messaging = FirebaseMessaging.instance;

  // Ask for notification permission
  final settings = await messaging.requestPermission();

  print('Notification permission: ${settings.authorizationStatus}');

  // Get the FCM token
  final fcmToken = await messaging.getToken();

  print('FCM TOKEN: $fcmToken');

  // Get currently logged-in user
  final user = Supabase.instance.client.auth.currentUser;

  if (user == null) {
    print('No logged-in user. Token not saved yet.');
    return;
  }

  // Save token to Supabase
  if (fcmToken != null) {
    await Supabase.instance.client
        .from('profiles')
        .update({'fcm_token': fcmToken})
        .eq('id', user.id);

    print('FCM token saved to Supabase');
  }
}