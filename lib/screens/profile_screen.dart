import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';
import 'digital_id_screen.dart';
import 'emergency_contacts_screen.dart';
import 'login_screen.dart';
import 'medical_information_profile_screen.dart';
import 'verify_digital_id_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  String _name = 'User';
  String _email = '';
  String _phone = '';

  bool _hideEmail = false;
  bool _hidePhone = false;
  bool _loading = true;

  static const String _hideEmailKey = 'trekcure_hide_email';
  static const String _hidePhoneKey = 'trekcure_hide_phone';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      return;
    }

    try {
      final profile = await _supabase
          .from('profiles')
          .select('full_name, phone_number')
          .eq('id', user.id)
          .maybeSingle();

      final prefs = await SharedPreferences.getInstance();

      if (!mounted) return;

      setState(() {
        _name = profile?['full_name']?.toString() ?? 'User';
        _phone = profile?['phone_number']?.toString() ?? '';
        _email = user.email ?? '';
        _hideEmail = prefs.getBool(_hideEmailKey) ?? false;
        _hidePhone = prefs.getBool(_hidePhoneKey) ?? false;
        _loading = false;
      });
    } catch (e) {
      debugPrint('PROFILE LOAD ERROR: $e');

      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  String get _displayEmail {
    if (_hideEmail) {
      return 'Email hidden';
    }

    return _email.isEmpty ? 'No email available' : _email;
  }

  String get _displayPhone {
    if (_hidePhone) {
      return 'Phone number hidden';
    }

    return _phone.isEmpty ? 'No phone number available' : _phone;
  }

  Future<void> _openPersonalInformation() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PersonalInformationScreen()),
    );

    await _loadProfile();
  }

  Future<void> _openMedicalInformation() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MedicalInformationProfileScreen(),
      ),
    );
  }

  void _openNotificationSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
    );
  }

  Future<void> _openPrivacySecurity() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PrivacySecurityScreen()),
    );

    await _loadProfile();
  }

  Future<void> _logout() async {
    try {
      await _supabase.auth.signOut();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      debugPrint('LOGOUT ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Unable to logout.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ======================================================
          // PROFILE CARD
          // ======================================================

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.person, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.verified,
                            color: Colors.white,
                            size: 16,
                          ),
                        ],
                      ),
                      const Text(
                        'Verified Traveler',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _displayEmail,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        _displayPhone,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ======================================================
          // PROFILE OPTIONS
          // ======================================================
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _tile(
                  Icons.badge_outlined,
                  'Personal Information',
                  _openPersonalInformation,
                ),

                // ==================================================
                // MEDICAL INFORMATION
                // ==================================================
                _tile(
                  Icons.medical_information_outlined,
                  'Medical Information',
                  _openMedicalInformation,
                  subtitle: 'View or update your medical information',
                ),

                _tile(Icons.contact_phone_outlined, 'Emergency Contacts', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EmergencyContactsScreen(),
                    ),
                  );
                }),

                _tile(Icons.qr_code, 'Digital Travel ID', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DigitalIdScreen()),
                  );
                }),

                _tile(
                  Icons.notifications_none,
                  'Notification Settings',
                  _openNotificationSettings,
                ),

                _tile(
                  Icons.privacy_tip_outlined,
                  'Privacy & Security',
                  _openPrivacySecurity,
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ======================================================
          // SCAN DIGITAL ID
          // ======================================================
          AppCard(
            padding: EdgeInsets.zero,
            child: _tile(Icons.qr_code_scanner, 'Scan Digital ID', () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const VerifyDigitalIdScreen(),
                ),
              );
            }),
          ),

          const SizedBox(height: 10),

          // ======================================================
          // LOGOUT
          // ======================================================
          AppCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.logout, color: AppColors.dangerRed),
              title: const Text(
                'Logout',
                style: TextStyle(color: AppColors.dangerRed),
              ),
              onTap: _logout,
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
    );
  }

  // ============================================================
  // TILE
  // ============================================================

  Widget _tile(
    IconData icon,
    String title,
    VoidCallback onTap, {
    String? subtitle,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textDark),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
            ),
      trailing: const Icon(
        Icons.chevron_right,
        size: 20,
        color: AppColors.textGrey,
      ),
      onTap: onTap,
    );
  }
}

// ==================================================================
// PERSONAL INFORMATION
// ==================================================================

class PersonalInformationScreen extends StatefulWidget {
  const PersonalInformationScreen({super.key});

  @override
  State<PersonalInformationScreen> createState() =>
      _PersonalInformationScreenState();
}

class _PersonalInformationScreenState extends State<PersonalInformationScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();

    _loadInformation();
  }

  Future<void> _loadInformation() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      return;
    }

    try {
      final profile = await _supabase
          .from('profiles')
          .select('full_name, phone_number')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      _nameController.text = profile?['full_name']?.toString() ?? '';

      _phoneController.text = profile?['phone_number']?.toString() ?? '';

      _emailController.text = user.email ?? '';

      setState(() {
        _loading = false;
      });
    } catch (e) {
      debugPrint('PERSONAL INFO LOAD ERROR: $e');

      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _message('Could not load personal information.');
    }
  }

  Future<void> _saveInformation() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      _message('You are not logged in.');
      return;
    }

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty) {
      _message('Please enter your full name.');
      return;
    }

    if (email.isEmpty) {
      _message('Please enter your email address.');
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await _supabase
          .from('profiles')
          .update({'full_name': name, 'phone_number': phone})
          .eq('id', user.id);

      final oldEmail = user.email ?? '';

      if (email != oldEmail) {
        await _supabase.auth.updateUser(UserAttributes(email: email));
      }

      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      _message(
        email != oldEmail
            ? 'Information saved. Check your new email for confirmation.'
            : 'Personal information updated successfully.',
      );

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      Navigator.pop(context);
    } on AuthException catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      _message(e.message);
    } catch (e) {
      debugPrint('SAVE PERSONAL INFO ERROR: $e');

      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      _message('Could not save your information.');
    }
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      ),
    );
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Personal Information',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white24,
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Your Personal Information',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _field(
                  controller: _nameController,
                  label: 'Full Name',
                  icon: Icons.person_outline,
                  keyboardType: TextInputType.name,
                ),
                _field(
                  controller: _emailController,
                  label: 'Email Address',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                _field(
                  controller: _phoneController,
                  label: 'Phone Number',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _saveInformation,
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Save Changes',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Email changes may require confirmation from the new email address.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                ),
              ],
            ),
    );
  }
}

// ==================================================================
// NOTIFICATION SETTINGS
// ==================================================================

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _notifications = true;
  bool _sound = true;
  bool _vibration = true;

  bool _loading = true;
  bool _testing = false;

  final NotificationService _service = NotificationService.instance;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final notifications = await _service.notificationsEnabled();

    final sound = await _service.soundEnabled();

    final vibration = await _service.vibrationEnabled();

    if (!mounted) return;

    setState(() {
      _notifications = notifications;
      _sound = sound;
      _vibration = vibration;
      _loading = false;
    });
  }

  Future<void> _setNotifications(bool value) async {
    await _service.setNotificationsEnabled(value);

    if (!mounted) return;

    setState(() {
      _notifications = value;

      if (!value) {
        _sound = false;
        _vibration = false;
      } else {
        _sound = true;
        _vibration = true;
      }
    });
  }

  Future<void> _setSound(bool value) async {
    await _service.setSoundEnabled(value);

    if (!mounted) return;

    setState(() {
      _sound = value;
    });
  }

  Future<void> _setVibration(bool value) async {
    await _service.setVibrationEnabled(value);

    if (!mounted) return;

    setState(() {
      _vibration = value;
    });
  }

  Future<void> _testNotification() async {
    if (!_notifications) {
      _message('Notifications are turned off.');
      return;
    }

    if (_testing) return;

    setState(() {
      _testing = true;
    });

    try {
      final success = await _service.showTestNotification();

      if (!mounted) return;

      _message(
        success ? 'Test notification sent.' : 'Notification was blocked.',
      );
    } catch (e) {
      debugPrint('TEST NOTIFICATION ERROR: $e');

      if (!mounted) return;

      _message('Could not send the test notification.');
    } finally {
      if (mounted) {
        setState(() {
          _testing = false;
        });
      }
    }
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notification Settings',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AppCard(
                  padding: EdgeInsets.zero,
                  child: SwitchListTile(
                    title: const Text(
                      'Notifications',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      _notifications
                          ? 'TrekCure notifications are enabled.'
                          : 'TrekCure notifications are disabled.',
                    ),
                    value: _notifications,
                    onChanged: _setNotifications,
                    activeTrackColor: AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(height: 14),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Sound'),
                        subtitle: const Text('Play notification sound.'),
                        value: _sound,
                        onChanged: _notifications ? _setSound : null,
                        activeTrackColor: AppColors.primaryGreen,
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Vibration'),
                        subtitle: const Text('Vibrate for notifications.'),
                        value: _vibration,
                        onChanged: _notifications ? _setVibration : null,
                        activeTrackColor: AppColors.primaryGreen,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(
                      Icons.notifications_active,
                      color: AppColors.infoBlue,
                    ),
                    title: const Text(
                      'Test Notification',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      _testing
                          ? 'Sending notification...'
                          : 'Send a real device notification.',
                    ),
                    trailing: _testing
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow),
                    onTap: _notifications && !_testing
                        ? _testNotification
                        : null,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.lightGreenBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'When notifications are enabled, TrekCure can send device notifications. '
                    'Sound and vibration follow your selections.',
                    style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                  ),
                ),
              ],
            ),
    );
  }
}

// ==================================================================
// PRIVACY & SECURITY
// ==================================================================

class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key});

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  static const String _hideEmailKey = 'trekcure_hide_email';

  static const String _hidePhoneKey = 'trekcure_hide_phone';

  static const String _locationSharingKey = 'trekcure_location_sharing';

  bool _hideEmail = false;
  bool _hidePhone = false;
  bool _locationSharing = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      _hideEmail = prefs.getBool(_hideEmailKey) ?? false;

      _hidePhone = prefs.getBool(_hidePhoneKey) ?? false;

      _locationSharing = prefs.getBool(_locationSharingKey) ?? true;

      _loading = false;
    });
  }

  Future<void> _setHideEmail(bool value) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_hideEmailKey, value);

    if (!mounted) return;

    setState(() {
      _hideEmail = value;
    });

    _message(value ? 'Email is now hidden.' : 'Email is now visible.');
  }

  Future<void> _setHidePhone(bool value) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_hidePhoneKey, value);

    if (!mounted) return;

    setState(() {
      _hidePhone = value;
    });

    _message(
      value ? 'Phone number is now hidden.' : 'Phone number is now visible.',
    );
  }

  Future<void> _setLocationSharing(bool value) async {
    if (!value) {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool(_locationSharingKey, false);

      if (!mounted) return;

      setState(() {
        _locationSharing = false;
      });

      _message('Location sharing is now off.');

      return;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      _message('Turn on Location Services on your device first.');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _message('Location permission was not granted.');
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_locationSharingKey, true);

    if (!mounted) return;

    setState(() {
      _locationSharing = true;
    });

    _message('Location sharing is now on.');
  }

  void _openChangePassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
    );
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Privacy & Security',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white24,
                        child: Icon(
                          Icons.security,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Protect your TrekCure account and privacy.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.lock_outline,
                          color: AppColors.primaryGreen,
                        ),
                        title: const Text(
                          'Account Security',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'Your account is protected by Supabase.',
                        ),
                        trailing: const Icon(
                          Icons.check_circle,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(
                          Icons.password_outlined,
                          color: AppColors.primaryGreen,
                        ),
                        title: const Text(
                          'Password',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text('Change your current password.'),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: AppColors.textGrey,
                        ),
                        onTap: _openChangePassword,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Hide Email'),
                        subtitle: Text(
                          _hideEmail
                              ? 'Email is hidden in profile displays.'
                              : 'Email is visible in profile displays.',
                        ),
                        value: _hideEmail,
                        onChanged: _setHideEmail,
                        activeTrackColor: AppColors.primaryGreen,
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Hide Phone Number'),
                        subtitle: Text(
                          _hidePhone
                              ? 'Phone number is hidden in profile displays.'
                              : 'Phone number is visible in profile displays.',
                        ),
                        value: _hidePhone,
                        onChanged: _setHidePhone,
                        activeTrackColor: AppColors.primaryGreen,
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Location Sharing'),
                        subtitle: Text(
                          _locationSharing
                              ? 'TrekCure is allowed to use your location.'
                              : 'TrekCure location sharing is off.',
                        ),
                        value: _locationSharing,
                        onChanged: _setLocationSharing,
                        activeTrackColor: AppColors.primaryGreen,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.lightGreenBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Your privacy choices are saved on this device.',
                    style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                  ),
                ),
              ],
            ),
    );
  }
}

// ==================================================================
// CHANGE PASSWORD
// ==================================================================

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  final TextEditingController _currentPasswordController =
      TextEditingController();

  final TextEditingController _newPasswordController = TextEditingController();

  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _hideCurrent = true;
  bool _hideNew = true;
  bool _hideConfirm = true;
  bool _saving = false;

  Future<void> _changePassword() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      _message('You are not logged in.');
      return;
    }

    final email = user.email;

    if (email == null || email.isEmpty) {
      _message('Your account email is unavailable.');
      return;
    }

    final currentPassword = _currentPasswordController.text;

    final newPassword = _newPasswordController.text;

    final confirmPassword = _confirmPasswordController.text;

    if (currentPassword.isEmpty) {
      _message('Enter your current password.');
      return;
    }

    if (newPassword.isEmpty) {
      _message('Enter a new password.');
      return;
    }

    if (newPassword.length < 6) {
      _message('New password must contain at least 6 characters.');
      return;
    }

    if (newPassword != confirmPassword) {
      _message('New passwords do not match.');
      return;
    }

    if (currentPassword == newPassword) {
      _message('New password must be different from the current password.');
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );

      if (response.user == null) {
        throw const AuthException('Current password is incorrect.');
      }

      await _supabase.auth.updateUser(UserAttributes(password: newPassword));

      if (!mounted) return;

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      setState(() {
        _saving = false;
      });

      _message('Password changed successfully.');

      await Future.delayed(const Duration(milliseconds: 700));

      if (!mounted) return;

      Navigator.pop(context);
    } on AuthException catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      _message(e.message);
    } catch (e) {
      debugPrint('PASSWORD CHANGE ERROR: $e');

      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      _message('Unable to change password.');
    }
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            icon: Icon(
              obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
            onPressed: onToggle,
          ),
        ),
      ),
    );
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Change Password',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white24,
                  child: Icon(
                    Icons.lock_outline,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Change Password',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Enter your current password and choose a new password.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _passwordField(
            controller: _currentPasswordController,
            label: 'Current Password',
            obscure: _hideCurrent,
            onToggle: () {
              setState(() {
                _hideCurrent = !_hideCurrent;
              });
            },
          ),
          _passwordField(
            controller: _newPasswordController,
            label: 'New Password',
            obscure: _hideNew,
            onToggle: () {
              setState(() {
                _hideNew = !_hideNew;
              });
            },
          ),
          _passwordField(
            controller: _confirmPasswordController,
            label: 'Confirm New Password',
            obscure: _hideConfirm,
            onToggle: () {
              setState(() {
                _hideConfirm = !_hideConfirm;
              });
            },
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _changePassword,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'Change Password',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
