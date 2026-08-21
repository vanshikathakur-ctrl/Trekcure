import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';
import 'map_crowd_screen.dart';
import 'sos_emergency_screen.dart';
import 'weather_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  String _userName = 'User';

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      return;
    }

    try {
      final profile = await supabase
          .from('profiles')
          .select('full_name')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        _userName = profile?['full_name'] ?? 'User';
      });
    } catch (e) {
      debugPrint('Could not load user name: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const Icon(Icons.menu, color: AppColors.textDark),

            const SizedBox(width: 12),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, $_userName  👋',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                Row(
                  children: const [
                    Icon(
                      Icons.location_on,
                      size: 13,
                      color: AppColors.textGrey,
                    ),
                    SizedBox(width: 2),
                    Text(
                      'Mumbai, India',
                      style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),

        actions: [
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none, color: AppColors.textDark),

                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: AppColors.dangerRed,
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      '2',
                      style: TextStyle(color: Colors.white, fontSize: 9),
                    ),
                  ),
                ),
              ],
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Safety status card
            AppCard(
              color: AppColors.lightGreenBg,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: AppColors.primaryGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield, color: Colors.white),
                  ),

                  const SizedBox(width: 14),

                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'You are Safe',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Safety Status: Low Risk',
                          style: TextStyle(color: AppColors.textGrey),
                        ),
                        Text(
                          'Updated just now',
                          style: TextStyle(
                            color: AppColors.textGrey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Weather + Crowd row
            Row(
              children: [
                Expanded(
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(Icons.cloud, color: AppColors.infoBlue),
                        SizedBox(height: 6),
                        Text(
                          '28°C',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Cloudy',
                          style: TextStyle(color: AppColors.textGrey),
                        ),
                        SizedBox(height: 6),
                        Text('Humidity: 75%', style: TextStyle(fontSize: 12)),
                        Text('Wind: 12 km/h', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Crowd Level',
                          style: TextStyle(
                            color: AppColors.textGrey,
                            fontSize: 12,
                          ),
                        ),

                        const SizedBox(height: 10),

                        Row(
                          children: const [
                            Icon(Icons.groups, color: AppColors.warningOrange),
                            SizedBox(width: 6),
                            Text(
                              'Moderate',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.warningOrange,
                              ),
                            ),
                          ],
                        ),

                        const Text(
                          '240 people',
                          style: TextStyle(fontSize: 12),
                        ),

                        const SizedBox(height: 8),

                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MapCrowdScreen(),
                            ),
                          ),
                          child: const Text(
                            'View Details',
                            style: TextStyle(
                              color: AppColors.primaryGreen,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Travel alert
            AppCard(
              color: AppColors.dangerBgLight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.dangerRed,
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text(
                              'Travel Alert',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Icon(Icons.chevron_right, size: 18),
                          ],
                        ),

                        const SizedBox(height: 2),

                        const Text(
                          'High crowd detected near\nGateway of India. Avoid if possible.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textGrey,
                          ),
                        ),

                        const SizedBox(height: 4),

                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MapCrowdScreen(),
                            ),
                          ),
                          child: const Text(
                            'View on Map >',
                            style: TextStyle(
                              color: AppColors.dangerRed,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              'Quick Actions',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),

            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _quickAction(
                  context,
                  Icons.map_outlined,
                  'Map',
                  AppColors.primaryGreen,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MapCrowdScreen()),
                  ),
                ),

                _quickAction(
                  context,
                  Icons.sos,
                  'SOS',
                  AppColors.dangerRed,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SosEmergencyScreen(),
                    ),
                  ),
                ),

                _quickAction(
                  context,
                  Icons.cloud_outlined,
                  'Weather',
                  AppColors.infoBlue,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WeatherScreen()),
                  ),
                ),

                _quickAction(
                  context,
                  Icons.person_outline,
                  'Contacts',
                  AppColors.textGrey,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),

      bottomNavigationBar: const AppBottomNav(currentIndex: 0),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _quickAction(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),

          const SizedBox(height: 6),

          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
