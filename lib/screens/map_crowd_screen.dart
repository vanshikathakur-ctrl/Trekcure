import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';

class MapCrowdScreen extends StatelessWidget {
  const MapCrowdScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.menu),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.cardGrey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const TextField(
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          icon: Icon(Icons.search, size: 20),
                          hintText: 'Search location...',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.filter_list),
                ],
              ),
            ),
            // Map placeholder — swap this container for a real GoogleMap /
            // flutter_map widget once you add the relevant package + API key.
            Expanded(
              flex: 3,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCEAF7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(Icons.map_outlined,
                          size: 64, color: Colors.blue.shade200),
                    ),
                    Positioned(
                      top: 40,
                      left: 60,
                      child: _crowdDot(AppColors.dangerRed, 'Gateway\nof India'),
                    ),
                    Positioned(
                      top: 100,
                      right: 50,
                      child: _crowdDot(AppColors.warningOrange, 'Colaba'),
                    ),
                    Positioned(
                      bottom: 50,
                      left: 40,
                      child: _crowdDot(const Color(0xFF3AAE58), 'Marine\nDrive'),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: Column(
                        children: [
                          _mapFab(Icons.layers_outlined),
                          const SizedBox(height: 8),
                          _mapFab(Icons.my_location),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  _LegendDot(color: Color(0xFF3AAE58), label: 'Low'),
                  SizedBox(width: 16),
                  _LegendDot(color: AppColors.warningOrange, label: 'Moderate'),
                  SizedBox(width: 16),
                  _LegendDot(color: AppColors.dangerRed, label: 'High'),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _crowdTile('Crowd at Gateway of India', 'High Crowd',
                      '247 people', AppColors.dangerRed, AppColors.dangerBgLight),
                  const SizedBox(height: 10),
                  _crowdTile('Crowd at Marine Drive', 'Moderate Crowd',
                      '120 people', AppColors.warningOrange, AppColors.warningBgLight),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }

  Widget _crowdDot(Color color, String label) {
    return Column(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
        const SizedBox(height: 2),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 9, color: AppColors.textDark)),
      ],
    );
  }

  Widget _mapFab(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4),
        ],
      ),
      child: Icon(icon, size: 18, color: AppColors.textDark),
    );
  }

  Widget _crowdTile(
      String title, String status, String people, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 4),
                Text(status,
                    style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                Text(people,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textGrey)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: color),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
