import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../screens/home_dashboard_screen.dart';
import '../screens/map_crowd_screen.dart';
import '../screens/sos_emergency_screen.dart';
import '../screens/weather_screen.dart';
import '../screens/profile_screen.dart';

/// Bottom navigation matching the mockup: Home, Map, SOS (raised center),
/// Weather, Profile. [currentIndex]: 0=Home,1=Map,2=SOS,3=Weather,4=Profile.
class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  const AppBottomNav({super.key, required this.currentIndex});

  void _go(BuildContext context, Widget screen, int index) {
    if (index == currentIndex) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) => screen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: Colors.white,
      elevation: 8,
      child: SizedBox(
        height: 64,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navIcon(context, Icons.home_rounded, 'Home', 0,
                const HomeDashboardScreen()),
            _navIcon(context, Icons.map_rounded, 'Map', 1,
                const MapCrowdScreen()),
            _sosIcon(context),
            _navIcon(context, Icons.cloud_outlined, 'Weather', 3,
                const WeatherScreen()),
            _navIcon(context, Icons.person_outline, 'Profile', 4,
                const ProfileScreen()),
          ],
        ),
      ),
    );
  }

  Widget _navIcon(
      BuildContext context, IconData icon, String label, int index, Widget screen) {
    final selected = currentIndex == index;
    final color = selected ? AppColors.primaryGreen : AppColors.textGrey;
    return InkWell(
      onTap: () => _go(context, screen, index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: color, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _sosIcon(BuildContext context) {
    return InkWell(
      onTap: () => _go(context, const SosEmergencyScreen(), 2),
      child: Container(
        width: 46,
        height: 46,
        decoration: const BoxDecoration(
          color: AppColors.dangerRed,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Text(
          'SOS',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
