import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';

class WeatherScreen extends StatelessWidget {
  const WeatherScreen({super.key});

  static const _forecast = [
    {'time': '10:00 AM', 'temp': '28°C', 'icon': Icons.wb_cloudy_outlined},
    {'time': '1:00 PM', 'temp': '30°C', 'icon': Icons.wb_sunny_outlined},
    {'time': '4:00 PM', 'temp': '27°C', 'icon': Icons.wb_cloudy_outlined},
    {'time': '7:00 PM', 'temp': '26°C', 'icon': Icons.grain},
    {'time': '10:00 PM', 'temp': '25°C', 'icon': Icons.grain},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: const [
            Icon(Icons.wb_cloudy_outlined),
            SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Weather', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 12, color: AppColors.textGrey),
                    Text('Mumbai, India',
                        style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                  ],
                )
              ],
            ),
          ],
        ),
        actions: const [
          Padding(padding: EdgeInsets.only(right: 16), child: Icon(Icons.refresh)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            color: const Color(0xFFDCEAF7),
            child: Column(
              children: const [
                Icon(Icons.wb_cloudy, size: 40, color: AppColors.infoBlue),
                SizedBox(height: 8),
                Text('28°C', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                Text('Cloudy', style: TextStyle(color: AppColors.textGrey)),
                SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatColumn(label: 'Humidity', value: '75%'),
                    _StatColumn(label: 'Wind', value: '12 km/h'),
                    _StatColumn(label: 'Feels Like', value: '31°C'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text("Today's Forecast",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: _forecast.map((f) {
                return ListTile(
                  leading: Icon(f['icon'] as IconData, color: AppColors.infoBlue),
                  title: Text(f['time'] as String),
                  trailing: Text(f['temp'] as String,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            color: AppColors.infoBgLight,
            child: Row(
              children: const [
                Icon(Icons.info_outline, color: AppColors.infoBlue),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Weather Alert', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('Rain expected during your travel. Carry umbrella and stay safe.',
                          style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  const _StatColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
      ],
    );
  }
}
