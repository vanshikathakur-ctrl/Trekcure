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
  // ANDROID CHANNEL IDS
  // ============================================================

  static const String _soundAndVibrationChannel =
      'trekcure_notifications_sound_vibration';

  static const String _soundOnlyChannel = 'trekcure_notifications_sound';

  static const String _vibrationOnlyChannel =
      'trekcure_notifications_vibration';

  static const String _silentChannel = 'trekcure_notifications_silent';

  // ============================================================
  // INITIALIZE
  // ============================================================

  Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);

    // flutter_local_notifications 22.x
    await _notificationsPlugin.initialize(settings: initializationSettings);

    // ==========================================================
    // ANDROID PERMISSION
    // ==========================================================

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    await androidPlugin?.requestNotificationsPermission();

    // ==========================================================
    // SOUND + VIBRATION CHANNEL
    // ==========================================================

    const AndroidNotificationChannel soundAndVibrationChannel =
        AndroidNotificationChannel(
          _soundAndVibrationChannel,
          'TrekCure Notifications',
          description: 'TrekCure notifications with sound and vibration.',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        );

    // ==========================================================
    // SOUND ONLY CHANNEL
    // ==========================================================

    const AndroidNotificationChannel soundOnlyChannel =
        AndroidNotificationChannel(
          _soundOnlyChannel,
          'TrekCure Notifications',
          description: 'TrekCure notifications with sound.',
          importance: Importance.high,
          playSound: true,
          enableVibration: false,
          showBadge: true,
        );

    // ==========================================================
    // VIBRATION ONLY CHANNEL
    // ==========================================================

    const AndroidNotificationChannel vibrationOnlyChannel =
        AndroidNotificationChannel(
          _vibrationOnlyChannel,
          'TrekCure Notifications',
          description: 'TrekCure notifications with vibration.',
          importance: Importance.high,
          playSound: false,
          enableVibration: true,
          showBadge: true,
        );

    // ==========================================================
    // SILENT CHANNEL
    // ==========================================================

    const AndroidNotificationChannel silentChannel = AndroidNotificationChannel(
      _silentChannel,
      'TrekCure Notifications',
      description: 'TrekCure silent notifications.',
      importance: Importance.high,
      playSound: false,
      enableVibration: false,
      showBadge: true,
    );

    await androidPlugin?.createNotificationChannel(soundAndVibrationChannel);

    await androidPlugin?.createNotificationChannel(soundOnlyChannel);

    await androidPlugin?.createNotificationChannel(vibrationOnlyChannel);

    await androidPlugin?.createNotificationChannel(silentChannel);

    // ==========================================================
    // IOS PERMISSIONS
    // ==========================================================

    final IOSFlutterLocalNotificationsPlugin? iosPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);
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

    // If master notifications are turned off,
    // sound and vibration are also disabled.
    if (!value) {
      await prefs.setBool(_soundKey, false);

      await prefs.setBool(_vibrationKey, false);
    } else {
      // Restore both when notifications are enabled.
      await prefs.setBool(_soundKey, true);

      await prefs.setBool(_vibrationKey, true);
    }
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
  // SELECT CHANNEL
  // ============================================================

  String _getChannelId({required bool soundOn, required bool vibrationOn}) {
    if (soundOn && vibrationOn) {
      return _soundAndVibrationChannel;
    }

    if (soundOn && !vibrationOn) {
      return _soundOnlyChannel;
    }

    if (!soundOn && vibrationOn) {
      return _vibrationOnlyChannel;
    }

    return _silentChannel;
  }

  // ============================================================
  // TEST NOTIFICATION
  // ============================================================

  Future<bool> showTestNotification() async {
    final bool notificationsOn = await notificationsEnabled();

    if (!notificationsOn) {
      return false;
    }

    final bool soundOn = await soundEnabled();

    final bool vibrationOn = await vibrationEnabled();

    final String channelId = _getChannelId(
      soundOn: soundOn,
      vibrationOn: vibrationOn,
    );

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          channelId,
          'TrekCure Notifications',
          channelDescription: 'TrekCure safety and weather notifications.',
          importance: Importance.high,
          priority: Priority.high,
          playSound: soundOn,
          enableVibration: vibrationOn,
          autoCancel: true,
          showWhen: true,
          icon: '@mipmap/ic_launcher',
        );

    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: soundOn,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id: 1001,
      title: 'TrekCure Test Notification',
      body: 'Notifications are working correctly.',
      notificationDetails: notificationDetails,
    );

    return true;
  }

  // ============================================================
  // REAL NOTIFICATION
  // ============================================================

  Future<bool> showNotification({
    required String title,
    required String body,
    int? id,
  }) async {
    final bool notificationsOn = await notificationsEnabled();

    // Master switch OFF = do not send anything.
    if (!notificationsOn) {
      return false;
    }

    final bool soundOn = await soundEnabled();

    final bool vibrationOn = await vibrationEnabled();

    final String channelId = _getChannelId(
      soundOn: soundOn,
      vibrationOn: vibrationOn,
    );

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          channelId,
          'TrekCure Notifications',
          channelDescription: 'TrekCure safety and travel notifications.',
          importance: Importance.high,
          priority: Priority.high,
          playSound: soundOn,
          enableVibration: vibrationOn,
          autoCancel: true,
          showWhen: true,
          icon: '@mipmap/ic_launcher',
        );

    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: soundOn,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final int notificationId =
        id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000);

    await _notificationsPlugin.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
    );

    return true;
  }
}
