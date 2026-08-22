import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  NotificationService._privateConstructor();

  static final NotificationService instance =
      NotificationService._privateConstructor();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String _notificationsKey = 'notifications_enabled';
  static const String _soundKey = 'sound_enabled';
  static const String _vibrationKey = 'vibration_enabled';

  // ============================================================
  // INITIALIZE
  // ============================================================

  Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(settings: initializationSettings);
  }

  // ============================================================
  // GET SETTINGS
  // ============================================================

  Future<bool> notificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getBool(_notificationsKey) ?? true;
  }

  Future<bool> soundEnabled() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getBool(_soundKey) ?? true;
  }

  Future<bool> vibrationEnabled() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getBool(_vibrationKey) ?? true;
  }

  // ============================================================
  // SET SETTINGS
  // ============================================================

  Future<void> setNotificationsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_notificationsKey, value);
  }

  Future<void> setSoundEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_soundKey, value);
  }

  Future<void> setVibrationEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_vibrationKey, value);
  }

  // ============================================================
  // TEST NOTIFICATION
  // ============================================================

  Future<void> showTestNotification() async {
    final notificationsOn = await notificationsEnabled();

    if (!notificationsOn) {
      return;
    }

    final soundOn = await soundEnabled();

    final vibrationOn = await vibrationEnabled();

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'trekcure_notifications',
          'TrekCure Notifications',
          channelDescription: 'TrekCure safety and weather notifications',
          importance: Importance.high,
          priority: Priority.high,
          playSound: soundOn,
          enableVibration: vibrationOn,
        );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.show(
      id: 1001,
      title: 'TrekCure Test Notification',
      body: 'Notifications are working correctly.',
      notificationDetails: notificationDetails,
    );
  }
}
