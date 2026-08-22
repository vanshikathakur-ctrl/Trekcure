import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/mesh_service.dart';
import '../theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  RealtimeChannel? _channel;

  StreamSubscription<Map<String, dynamic>>? _offlineSosSubscription;

  final List<Map<String, dynamic>> _sosNotifications = [];

  @override
  void initState() {
    super.initState();

    // Online SOS via Supabase
    _listenForSos();

    // Offline SOS via Bluetooth mesh
    _listenForOfflineSos();
  }

  // ============================================================
  // ONLINE SOS LISTENER - SUPABASE REALTIME
  // ============================================================

  void _listenForSos() {
    debugPrint('STARTING SOS REALTIME LISTENER...');

    _channel = _supabase
        .channel('sos-alerts-${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'sos_alerts',
          callback: (payload) {
            debugPrint(
              'SOS REALTIME EVENT RECEIVED: ${payload.newRecord}',
            );

            final newSos = payload.newRecord;

            if (!mounted) return;

            setState(() {
              _sosNotifications.insert(0, {
                'id': newSos['id'],
                'title': 'SOS Emergency Alert',
                'subtitle':
                    'A tourist has triggered an emergency SOS alert in Mumbai.',
                'time': 'Just now',
              });
            });

            _showSosDialog();
          },
        )
        .subscribe((status, error) {
          debugPrint('SOS REALTIME STATUS: $status');

          if (error != null) {
            debugPrint('SOS REALTIME ERROR: $error');
          }
        });
  }

  // ============================================================
  // OFFLINE SOS LISTENER - BLUETOOTH MESH
  // ============================================================

  void _listenForOfflineSos() {
    debugPrint('STARTING OFFLINE MESH SOS LISTENER...');

    _offlineSosSubscription =
        MeshService.instance.sosStream.listen((sos) {
      debugPrint('==============================');
      debugPrint('OFFLINE SOS RECEIVED IN UI');
      debugPrint('Sender: ${sos['senderName']}');
      debugPrint('Payload: ${sos['payload']}');
      debugPrint('==============================');

      if (!mounted) return;

      final senderName = sos['senderName']?.toString() ?? 'Nearby user';

      setState(() {
        _sosNotifications.insert(0, {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'title': 'Offline SOS Emergency',
          'subtitle':
              '$senderName has triggered an emergency SOS nearby.',
          'time': 'Just now',
        });
      });

      _showOfflineSosDialog(senderName);
    });
  }

  // ============================================================
  // ONLINE SOS DIALOG
  // ============================================================

  void _showSosDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.emergency,
                color: AppColors.dangerRed,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'SOS ALERT!',
                  style: TextStyle(
                    color: AppColors.dangerRed,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'A tourist has triggered an emergency SOS alert in Mumbai.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.dangerRed,
              ),
              child: const Text('Dismiss'),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // OFFLINE SOS DIALOG
  // ============================================================

  void _showOfflineSosDialog(String senderName) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.emergency,
                color: AppColors.dangerRed,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'OFFLINE SOS ALERT!',
                  style: TextStyle(
                    color: AppColors.dangerRed,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            '$senderName has triggered an emergency SOS nearby through the offline mesh network.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.dangerRed,
              ),
              child: const Text('Dismiss'),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // CLEANUP
  // ============================================================

  @override
  void dispose() {
    _offlineSosSubscription?.cancel();

    if (_channel != null) {
      _supabase.removeChannel(_channel!);
    }

    super.dispose();
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Today',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textGrey,
            ),
          ),

          const SizedBox(height: 10),

          // LIVE ONLINE + OFFLINE SOS NOTIFICATIONS
          ..._sosNotifications.map(
            (notification) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _notifCard(
                icon: Icons.emergency,
                color: AppColors.dangerRed,
                bg: AppColors.dangerBgLight,
                title: notification['title'],
                subtitle: notification['subtitle'],
                time: notification['time'],
              ),
            ),
          ),

          // STATIC PROTOTYPE NOTIFICATIONS
          _notifCard(
            icon: Icons.groups,
            color: AppColors.dangerRed,
            bg: AppColors.dangerBgLight,
            title: 'Crowd Alert',
            subtitle:
                'High crowd density detected\nnear Gateway of India.',
            time: '10:30 AM',
          ),

          const SizedBox(height: 10),

          _notifCard(
            icon: Icons.cloud,
            color: AppColors.infoBlue,
            bg: AppColors.infoBgLight,
            title: 'Weather Alert',
            subtitle:
                'Heavy rain expected in\nyour travel area.',
            time: '9:15 AM',
          ),

          const SizedBox(height: 10),

          _notifCard(
            icon: Icons.warning_amber_rounded,
            color: AppColors.warningOrange,
            bg: AppColors.warningBgLight,
            title: 'Safety Alert',
            subtitle:
                'An emergency situation\nreported near Colaba.',
            time: '8:05 AM',
          ),

          const SizedBox(height: 20),

          const Text(
            'Yesterday',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textGrey,
            ),
          ),

          const SizedBox(height: 10),

          _notifCard(
            icon: Icons.check_circle,
            color: AppColors.primaryGreen,
            bg: AppColors.lightGreenBg,
            title: 'Travel Update',
            subtitle:
                'Roads are clear on your\nselected route.',
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
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textGrey,
            ),
          ),
        ],
      ),
    );
  }
}