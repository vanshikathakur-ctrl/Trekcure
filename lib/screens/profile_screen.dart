import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';
import 'digital_id_screen.dart';
import 'emergency_contacts_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name = 'User';
  String _email = '';
  String _phone = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return;

    try {
      final profile = await supabase
          .from('profiles')
          .select('full_name, phone_number')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        _name = profile?['full_name'] ?? 'User';
        _phone = profile?['phone_number'] ?? '';
        _email = user.email ?? '';
      });
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
  }

  void _openPersonalInformation() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PersonalInformationScreen()),
    );
  }

  void _openNotificationSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
    );
  }

  void _openPrivacySecurity() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PrivacySecurityScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                        _email,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        _phone,
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

          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _tile(
                  Icons.badge_outlined,
                  'Personal Information',
                  _openPersonalInformation,
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

          AppCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.logout, color: AppColors.dangerRed),
              title: const Text(
                'Logout',
                style: TextStyle(color: AppColors.dangerRed),
              ),
              onTap: () async {
                await Supabase.instance.client.auth.signOut();

                if (!context.mounted) return;

                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
    );
  }

  Widget _tile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textDark),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      trailing: const Icon(
        Icons.chevron_right,
        size: 20,
        color: AppColors.textGrey,
      ),
      onTap: onTap,
    );
  }
}

// ================================================================
// PERSONAL INFORMATION
// ================================================================

class PersonalInformationScreen extends StatefulWidget {
  const PersonalInformationScreen({super.key});

  @override
  State<PersonalInformationScreen> createState() =>
      _PersonalInformationScreenState();
}

class _PersonalInformationScreenState extends State<PersonalInformationScreen> {
  String _name = 'User';
  String _email = '';
  String _phone = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInformation();
  }

  Future<void> _loadInformation() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    try {
      final profile = await supabase
          .from('profiles')
          .select('full_name, phone_number')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        _name = profile?['full_name'] ?? 'User';
        _phone = profile?['phone_number'] ?? '';
        _email = user.email ?? '';
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading personal details: $e');

      if (!mounted) return;

      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load personal information.')),
      );
    }
  }

  Widget _info(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primaryGreen),
        title: Text(
          title,
          style: const TextStyle(color: AppColors.textGrey, fontSize: 12),
        ),
        subtitle: Text(
          value.isEmpty ? 'Not provided' : value,
          style: const TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
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
                const SizedBox(height: 20),
                _info(Icons.person_outline, 'Full Name', _name),
                _info(Icons.email_outlined, 'Email Address', _email),
                _info(Icons.phone_outlined, 'Phone Number', _phone),
              ],
            ),
    );
  }
}

// ================================================================
// NOTIFICATION SETTINGS
// ================================================================

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

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final service = NotificationService.instance;

    final notifications = await service.notificationsEnabled();

    final sound = await service.soundEnabled();
    final vibration = await service.vibrationEnabled();

    if (!mounted) return;

    setState(() {
      _notifications = notifications;
      _sound = sound;
      _vibration = vibration;
      _loading = false;
    });
  }

  Future<void> _setNotifications(bool value) async {
    await NotificationService.instance.setNotificationsEnabled(value);

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
    await NotificationService.instance.setSoundEnabled(value);

    if (!mounted) return;

    setState(() {
      _sound = value;
    });
  }

  Future<void> _setVibration(bool value) async {
    await NotificationService.instance.setVibrationEnabled(value);

    if (!mounted) return;

    setState(() {
      _vibration = value;
    });
  }

  Future<void> _testNotification() async {
    if (!_notifications) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Turn notifications on first.')),
      );
      return;
    }

    await NotificationService.instance.showTestNotification();

    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Test notification sent.')));
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
                    subtitle: const Text(
                      'Allow TrekCure to send notifications.',
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
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Vibration'),
                        subtitle: const Text('Vibrate for notifications.'),
                        value: _vibration,
                        onChanged: _notifications ? _setVibration : null,
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
                    subtitle: const Text('Send a real device notification.'),
                    trailing: const Icon(Icons.play_arrow),
                    onTap: _testNotification,
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
                    'When notifications are enabled, '
                    'TrekCure can show device notifications. '
                    'Sound and vibration follow your selections.',
                    style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                  ),
                ),
              ],
            ),
    );
  }
}

// ================================================================
// PRIVACY & SECURITY
// ================================================================

class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key});

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  bool _hideEmail = false;
  bool _hidePhone = false;
  bool _locationSharing = true;

  void _message(String message) {
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
                  child: Icon(Icons.security, color: Colors.white, size: 32),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Protect your TrekCure account and privacy.',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
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
                    'Authentication is handled through Supabase.',
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
                  subtitle: const Text(
                    'Use the login password reset flow to change it.',
                  ),
                  onTap: () {
                    _message('Use Forgot Password on the login screen.');
                  },
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
                  subtitle: const Text(
                    'Keep your email hidden in profile displays.',
                  ),
                  value: _hideEmail,
                  onChanged: (value) {
                    setState(() {
                      _hideEmail = value;
                    });
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Hide Phone Number'),
                  subtitle: const Text(
                    'Keep your phone number hidden in profile displays.',
                  ),
                  value: _hidePhone,
                  onChanged: (value) {
                    setState(() {
                      _hidePhone = value;
                    });
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Location Sharing'),
                  subtitle: const Text(
                    'Allow location-based TrekCure features.',
                  ),
                  value: _locationSharing,
                  onChanged: (value) {
                    setState(() {
                      _locationSharing = value;
                    });

                    _message(
                      value
                          ? 'Location sharing enabled.'
                          : 'Location sharing disabled.',
                    );
                  },
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
              'Review your privacy choices regularly. '
              'Some app features, such as location-based '
              'weather and safety services, may require '
              'location access.',
              style: TextStyle(fontSize: 12, color: AppColors.textGrey),
            ),
          ),
        ],
      ),
    );
  }
}
