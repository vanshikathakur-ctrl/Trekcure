import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Notifications',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Today',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textGrey)),
          const SizedBox(height: 10),
          _notifCard(
            icon: Icons.groups,
            color: AppColors.dangerRed,
            bg: AppColors.dangerBgLight,
            title: 'Crowd Alert',
            subtitle: 'High crowd density detected\nnear Gateway of India.',
            time: '10:30 AM',
          ),
          const SizedBox(height: 10),
          _notifCard(
            icon: Icons.cloud,
            color: AppColors.infoBlue,
            bg: AppColors.infoBgLight,
            title: 'Weather Alert',
            subtitle: 'Heavy rain expected in\nyour travel area.',
            time: '9:15 AM',
          ),
          const SizedBox(height: 10),
          _notifCard(
            icon: Icons.warning_amber_rounded,
            color: AppColors.warningOrange,
            bg: AppColors.warningBgLight,
            title: 'Safety Alert',
            subtitle: 'An emergency situation\nreported near Colaba.',
            time: '8:05 AM',
          ),
          const SizedBox(height: 20),
          const Text('Yesterday',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textGrey)),
          const SizedBox(height: 10),
          _notifCard(
            icon: Icons.check_circle,
            color: AppColors.primaryGreen,
            bg: AppColors.lightGreenBg,
            title: 'Travel Update',
            subtitle: 'Roads are clear on your\nselected route.',
            time: '7:30 PM',
          ),
        ],
      ),
    );
  }

  Widget _notifCard({
    required IconData icon,
    required Color color,
    required Color bg,
    required String title,
    required String subtitle,
    required String time,
  }) {
    return AppCard(
      color: bg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
              ],
            ),
          ),
          Text(time, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
        ],
      ),
    );
  }
}
