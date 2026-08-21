import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';
import 'sos_activated_screen.dart';

class SosEmergencyScreen extends StatefulWidget {
  const SosEmergencyScreen({super.key});

  @override
  State<SosEmergencyScreen> createState() => _SosEmergencyScreenState();
}

class _SosEmergencyScreenState extends State<SosEmergencyScreen> {
  Timer? _holdTimer;
  double _progress = 0;
  bool _isSendingSos = false;

  final SupabaseClient _supabase = Supabase.instance.client;

  void _startHold() {
    if (_isSendingSos) return;

    _holdTimer?.cancel();

    setState(() {
      _progress = 0;
    });

    _holdTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        setState(() {
          _progress += 0.1 / 3;
        });

        if (_progress >= 1) {
          timer.cancel();

          setState(() {
            _progress = 1;
          });

          _triggerSos();
        }
      },
    );
  }

  void _cancelHold() {
    if (_isSendingSos) return;

    _holdTimer?.cancel();

    setState(() {
      _progress = 0;
    });
  }

 Future<void> _triggerSos() async {
  if (_isSendingSos) return;

  setState(() {
    _isSendingSos = true;
  });

  try {
    final user = _supabase.auth.currentUser;

    debugPrint('CURRENT USER: ${user?.id}');

if (user == null) {
  throw Exception('You must be logged in to trigger an SOS.');
}

// Make sure this user has a profile before creating an SOS.
await _supabase.from('profiles').upsert({
  'id': user.id,
  'full_name': user.userMetadata?['full_name'] ?? 'Prototype User',
});

debugPrint('PROFILE VERIFIED');
debugPrint('INSERTING SOS INTO SUPABASE...');
    final response = await _supabase
        .from('sos_alerts')
        .insert({
          'user_id': user.id,
          'location': 'POINT(72.8777 19.0760)',
          'status': 'active',
        })
        .select()
        .single();

    debugPrint('SOS RESPONSE: $response');

    final sosId = response['id'] as String;

    debugPrint('SOS CREATED SUCCESSFULLY');
    debugPrint('SOS ID: $sosId');

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SosActivatedScreen(
          sosId: sosId,
        ),
      ),
    );
  } catch (e, stackTrace) {
    debugPrint('SOS ERROR: $e');
    debugPrint('STACK TRACE: $stackTrace');

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to activate SOS: $e'),
        backgroundColor: AppColors.dangerRed,
      ),
    );
  } finally {
    if (mounted) {
      setState(() {
        _isSendingSos = false;
        _progress = 0;
      });
    }
  }
}

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'SOS Emergency',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.info_outline),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 12),
            GestureDetector(
              onLongPressStart: (_) => _startHold(),
              onLongPressEnd: (_) => _cancelHold(),
              child: SizedBox(
                width: 180,
                height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 180,
                      height: 180,
                      child: CircularProgressIndicator(
                        value: _progress,
                        strokeWidth: 6,
                        backgroundColor: AppColors.border,
                        color: AppColors.dangerRed,
                      ),
                    ),
                    Container(
                      width: 140,
                      height: 140,
                      decoration: const BoxDecoration(
                        color: AppColors.dangerRed,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: _isSendingSos
                          ? const SizedBox(
                              width: 30,
                              height: 30,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : const Text(
                              'SOS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isSendingSos
                  ? 'Sending emergency alert...'
                  : 'Press and hold for 3 seconds',
              style: const TextStyle(
                color: AppColors.textGrey,
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: _statusChip(
                    Icons.location_on,
                    'Location',
                    'Mumbai',
                    AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statusChip(
                    Icons.wifi,
                    'Connection',
                    'Online',
                    AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statusChip(
                    Icons.battery_std,
                    'Battery',
                    '76%',
                    AppColors.primaryGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Emergency Contacts',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text(
                          'Manage',
                          style: TextStyle(
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    '2 contacts will be notified',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textGrey,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _avatar(Colors.blue.shade100, Icons.person),
                      const SizedBox(width: 8),
                      _avatar(Colors.pink.shade100, Icons.person),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
    );
  }

  Widget _statusChip(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        vertical: 12,
        horizontal: 8,
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 16,
            color: AppColors.textGrey,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textGrey,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(Color bg, IconData icon) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: bg,
      child: Icon(
        icon,
        color: Colors.white,
      ),
    );
  }
}