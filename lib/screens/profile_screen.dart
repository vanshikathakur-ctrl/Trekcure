import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';
import 'digital_id_screen.dart';
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

    if (user == null) {
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
      });
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
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
          // ======================================================
          // USER PROFILE CARD
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
                      // NAME
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

                          const SizedBox(width: 6),

                          const Icon(
                            Icons.verified,
                            color: Colors.white,
                            size: 16,
                          ),
                        ],
                      ),

                      // ROLE
                      const Text(
                        'Verified Traveler',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),

                      const SizedBox(height: 6),

                      // EMAIL
                      Text(
                        _email,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),

                      // PHONE
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

          // ======================================================
          // PROFILE OPTIONS
          // ======================================================
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _tile(Icons.badge_outlined, 'Personal Information', () {}),

                _tile(
                  Icons.contact_phone_outlined,
                  'Emergency Contacts',
                  () {},
                ),

                _tile(Icons.qr_code, 'Digital Travel ID', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DigitalIdScreen()),
                  );
                }),

                _tile(Icons.notifications_none, 'Notification Settings', () {}),

                _tile(Icons.privacy_tip_outlined, 'Privacy & Security', () {}),

                _tile(Icons.settings_outlined, 'App Settings', () {}),
              ],
            ),
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
