import 'package:shared_preferences/shared_preferences.dart';

class PrivacyService {
  PrivacyService._();

  static const String _hideEmailKey = 'privacy_hide_email';

  static const String _hidePhoneKey = 'privacy_hide_phone';

  static const String _locationSharingKey = 'privacy_location_sharing';

  // ============================================================
  // HIDE EMAIL
  // ============================================================

  static Future<bool> hideEmailEnabled() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getBool(_hideEmailKey) ?? false;
  }

  static Future<void> setHideEmail(bool value) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_hideEmailKey, value);
  }

  // ============================================================
  // HIDE PHONE
  // ============================================================

  static Future<bool> hidePhoneEnabled() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getBool(_hidePhoneKey) ?? false;
  }

  static Future<void> setHidePhone(bool value) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_hidePhoneKey, value);
  }

  // ============================================================
  // LOCATION SHARING
  // ============================================================

  static Future<bool> locationSharingEnabled() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getBool(_locationSharingKey) ?? true;
  }

  static Future<void> setLocationSharing(bool value) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_locationSharingKey, value);
  }
}
