import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';
import 'emergency_contacts_screen.dart';
import 'offline_sos_screen.dart';
import 'sos_activated_screen.dart';

class SosEmergencyScreen extends StatefulWidget {
  const SosEmergencyScreen({super.key});

  @override
  State<SosEmergencyScreen> createState() =>
      _SosEmergencyScreenState();
}

class _SosEmergencyScreenState
    extends State<SosEmergencyScreen> {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  Timer? _holdTimer;

  double _progress = 0;

  bool _isSendingSos = false;
  bool _loadingContacts = true;

  int _emergencyContactCount = 0;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadEmergencyContacts();
  }

  // ============================================================
  // LOAD EMERGENCY CONTACTS
  // ============================================================

  Future<void> _loadEmergencyContacts() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _emergencyContactCount = 0;
        _loadingContacts = false;
      });

      return;
    }

    try {
      final List<dynamic> contacts =
          await _supabase
              .from('emergency_contacts')
              .select('id')
              .eq(
                'user_id',
                user.id,
              );

      if (!mounted) return;

      setState(() {
        _emergencyContactCount =
            contacts.length;

        _loadingContacts = false;
      });
    } catch (e) {
      debugPrint(
        'EMERGENCY CONTACT LOAD ERROR: $e',
      );

      if (!mounted) return;

      setState(() {
        _emergencyContactCount = 0;
        _loadingContacts = false;
      });
    }
  }

  // ============================================================
  // MANAGE EMERGENCY CONTACTS
  // ============================================================

  Future<void> _manageEmergencyContacts() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const EmergencyContactsScreen(),
      ),
    );

    await _loadEmergencyContacts();
  }

  // ============================================================
  // CONTACT LABEL
  // ============================================================

  String get _contactMessage {
    if (_loadingContacts) {
      return 'Loading emergency contacts...';
    }

    if (_emergencyContactCount == 0) {
      return 'No emergency contacts added';
    }

    if (_emergencyContactCount == 1) {
      return '1 contact will be notified';
    }

    return '$_emergencyContactCount contacts will be notified';
  }

  // ============================================================
  // SHOW SOS INFORMATION
  // ============================================================

  void _showSosInfo() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AppColors.primaryGreen,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'How SOS Emergency Works',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                _infoStep(
                  icon: Icons.touch_app_outlined,
                  title: '1. Press and hold SOS',
                  text:
                      'Press and hold the red SOS button for 3 seconds to prevent accidental activation.',
                ),
                const SizedBox(height: 14),
                _infoStep(
                  icon: Icons.warning_amber_rounded,
                  title: '2. Emergency alert is created',
                  text:
                      'After the 3-second hold, TrekCure creates an emergency SOS alert for your account.',
                ),
                const SizedBox(height: 14),
                _infoStep(
                  icon: Icons.people_outline,
                  title: '3. Emergency contacts are notified',
                  text:
                      _emergencyContactCount == 0
                          ? 'No emergency contacts are currently saved. Add contacts using Manage.'
                          : '$_emergencyContactCount emergency contact${_emergencyContactCount == 1 ? '' : 's'} will be notified.',
                ),
                const SizedBox(height: 14),
                _infoStep(
                  icon: Icons.notifications_active_outlined,
                  title: '4. Online emergency notification',
                  text:
                      'When you are online, TrekCure sends the SOS notification through the configured notification service.',
                ),
                const SizedBox(height: 14),
                _infoStep(
                  icon: Icons.wifi_off_outlined,
                  title: '5. Offline SOS',
                  text:
                      'When normal internet connectivity is unavailable, use Offline SOS to access the offline emergency flow.',
                ),
                const SizedBox(height: 14),
                _infoStep(
                  icon: Icons.location_on_outlined,
                  title: '6. Location',
                  text:
                      'The SOS alert includes the location currently configured by the app for the emergency record.',
                ),
                const SizedBox(height: 14),
                _infoStep(
                  icon: Icons.cancel_outlined,
                  title: 'Important',
                  text:
                      'Do not press the SOS button unless you need emergency assistance. Use Manage to keep your emergency contacts up to date.',
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // INFO STEP
  // ============================================================

  Widget _infoStep({
    required IconData icon,
    required String title,
    required String text,
  }) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.lightGreenBg,
            borderRadius:
                BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: AppColors.primaryGreen,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textGrey,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // HOLD TO TRIGGER SOS
  // ============================================================

  void _startHold() {
    if (_isSendingSos) {
      return;
    }

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

  // ============================================================
  // CANCEL HOLD
  // ============================================================

  void _cancelHold() {
    if (_isSendingSos) {
      return;
    }

    _holdTimer?.cancel();

    if (!mounted) return;

    setState(() {
      _progress = 0;
    });
  }

  // ============================================================
  // TRIGGER SOS
  // ============================================================

  Future<void> _triggerSos() async {
    if (_isSendingSos) {
      return;
    }

    setState(() {
      _isSendingSos = true;
    });

    try {
      final user =
          _supabase.auth.currentUser;

      debugPrint(
        'CURRENT USER: ${user?.id}',
      );

      if (user == null) {
        throw Exception(
          'You must be logged in to trigger an SOS.',
        );
      }

      // ========================================================
      // ENSURE PROFILE EXISTS
      // ========================================================

      await _supabase
          .from('profiles')
          .upsert({
        'id': user.id,
        'full_name':
            user.userMetadata?['full_name'] ??
                'Prototype User',
      });

      debugPrint(
        'PROFILE VERIFIED',
      );

      // ========================================================
      // CREATE SOS
      // ========================================================

      debugPrint(
        'INSERTING SOS INTO SUPABASE...',
      );

      final response =
          await _supabase
              .from('sos_alerts')
              .insert({
        'user_id': user.id,
        'location':
            'POINT(72.8777 19.0760)',
        'status': 'active',
      })
              .select()
              .single();

      debugPrint(
        'SOS RESPONSE: $response',
      );

      final String sosId =
          response['id'].toString();

      debugPrint(
        'SOS CREATED SUCCESSFULLY',
      );

      debugPrint(
        'SOS ID: $sosId',
      );

      // ========================================================
      // SEND FCM SOS NOTIFICATION
      // ========================================================

      debugPrint(
        'CALLING FCM SOS FUNCTION...',
      );

      final notificationResponse =
          await _supabase.functions.invoke(
        'send-fcm-sos',
        body: {
          'sos_id': sosId,
        },
      );

      debugPrint(
        'FCM FUNCTION RESPONSE: '
        '${notificationResponse.data}',
      );

      if (!mounted) return;

      // ========================================================
      // OPEN SOS ACTIVATED SCREEN
      // ========================================================

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              SosActivatedScreen(
            sosId: sosId,
          ),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint(
        'SOS ERROR: $e',
      );

      debugPrint(
        'STACK TRACE: $stackTrace',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Failed to activate SOS: $e',
          ),
          backgroundColor:
              AppColors.dangerRed,
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

  // ============================================================
  // STATUS CHIP
  // ============================================================

  Widget _statusChip(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return AppCard(
      padding:
          const EdgeInsets.symmetric(
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
              fontWeight:
                  FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CONTACT AVATAR
  // ============================================================

  Widget _contactAvatar(
    int index,
  ) {
    final List<Color> colors = [
      Colors.blue.shade100,
      Colors.pink.shade100,
      Colors.orange.shade100,
      Colors.purple.shade100,
      Colors.teal.shade100,
    ];

    return CircleAvatar(
      radius: 18,
      backgroundColor:
          colors[index % colors.length],
      child: const Icon(
        Icons.person,
        color: Colors.white,
      ),
    );
  }

  // ============================================================
  // CONTACT AVATARS
  // ============================================================

  Widget _buildContactAvatars() {
    if (_loadingContacts) {
      return const SizedBox(
        height: 36,
        width: 36,
        child:
            CircularProgressIndicator(
          strokeWidth: 2,
        ),
      );
    }

    if (_emergencyContactCount == 0) {
      return Container(
        width: 36,
        height: 36,
        decoration:
            BoxDecoration(
          color: Colors.grey.shade200,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.person_off_outlined,
          size: 18,
          color:
              AppColors.textGrey,
        ),
      );
    }

    final int visibleCount =
        _emergencyContactCount > 5
            ? 5
            : _emergencyContactCount;

    return Row(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        for (int i = 0;
            i < visibleCount;
            i++)
          Padding(
            padding:
                EdgeInsets.only(
              right:
                  i == visibleCount - 1
                      ? 0
                      : 8,
            ),
            child:
                _contactAvatar(i),
          ),
        if (_emergencyContactCount > 5)
          Padding(
            padding:
                const EdgeInsets.only(
              left: 8,
            ),
            child: CircleAvatar(
              radius: 18,
              backgroundColor:
                  Colors.grey.shade200,
              child: Text(
                '+${_emergencyContactCount - 5}',
                style:
                    const TextStyle(
                  fontSize: 11,
                  fontWeight:
                      FontWeight.bold,
                  color:
                      AppColors.textGrey,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _holdTimer?.cancel();

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar:
          AppBar(
        automaticallyImplyLeading:
            false,
        title:
            const Text(
          'SOS Emergency',
          style:
              TextStyle(
            fontWeight:
                FontWeight.bold,
            fontSize:
                16,
          ),
        ),
        actions: [
          Padding(
            padding:
                const EdgeInsets.only(
              right: 16,
            ),
            child: IconButton(
              onPressed:
                  _showSosInfo,
              tooltip:
                  'How SOS works',
              icon:
                  const Icon(
                Icons.info_outline,
              ),
            ),
          ),
        ],
      ),

      body:
          SingleChildScrollView(
        padding:
            const EdgeInsets.all(24),
        child:
            Column(
          children: [
            const SizedBox(
              height: 12,
            ),

            // ==================================================
            // SOS BUTTON
            // ==================================================

            GestureDetector(
              onLongPressStart:
                  (_) => _startHold(),
              onLongPressEnd:
                  (_) => _cancelHold(),
              child:
                  SizedBox(
                width: 180,
                height: 180,
                child:
                    Stack(
                  alignment:
                      Alignment.center,
                  children: [
                    SizedBox(
                      width: 180,
                      height: 180,
                      child:
                          CircularProgressIndicator(
                        value:
                            _progress,
                        strokeWidth:
                            6,
                        backgroundColor:
                            AppColors.border,
                        color:
                            AppColors.dangerRed,
                      ),
                    ),
                    Container(
                      width: 140,
                      height: 140,
                      decoration:
                          const BoxDecoration(
                        color:
                            AppColors.dangerRed,
                        shape:
                            BoxShape.circle,
                      ),
                      alignment:
                          Alignment.center,
                      child:
                          _isSendingSos
                              ? const SizedBox(
                                  width: 30,
                                  height: 30,
                                  child:
                                      CircularProgressIndicator(
                                    color:
                                        Colors.white,
                                    strokeWidth: 3,
                                  ),
                                )
                              : const Text(
                                  'SOS',
                                  style:
                                      TextStyle(
                                    color:
                                        Colors.white,
                                    fontSize:
                                        28,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            Text(
              _isSendingSos
                  ? 'Sending emergency alert...'
                  : 'Press and hold for 3 seconds',
              style:
                  const TextStyle(
                color:
                    AppColors.textGrey,
              ),
            ),

            const SizedBox(
              height: 28,
            ),

            // ==================================================
            // STATUS
            // ==================================================

            Row(
              children: [
                Expanded(
                  child:
                      _statusChip(
                    Icons.location_on,
                    'Location',
                    'Mumbai',
                    AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                Expanded(
                  child:
                      _statusChip(
                    Icons.wifi,
                    'Connection',
                    'Online',
                    AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                Expanded(
                  child:
                      _statusChip(
                    Icons.battery_std,
                    'Battery',
                    '76%',
                    AppColors.primaryGreen,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 20,
            ),

            // ==================================================
            // OFFLINE SOS
            // ==================================================

            SizedBox(
              width:
                  double.infinity,
              child:
                  OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const OfflineSosScreen(),
                    ),
                  );
                },
                icon:
                    const Icon(
                  Icons.wifi_off,
                ),
                label:
                    const Text(
                  'Offline SOS',
                ),
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            // ==================================================
            // EMERGENCY CONTACTS
            // ==================================================

            AppCard(
              child:
                  Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Emergency Contacts',
                        style:
                            TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed:
                            _manageEmergencyContacts,
                        child:
                            const Text(
                          'Manage',
                          style:
                              TextStyle(
                            color:
                                AppColors.primaryGreen,
                          ),
                        ),
                      ),
                    ],
                  ),

                  Text(
                    _contactMessage,
                    style:
                        const TextStyle(
                      fontSize: 12,
                      color:
                          AppColors.textGrey,
                    ),
                  ),

                  const SizedBox(
                    height: 10,
                  ),

                  _buildContactAvatars(),
                ],
              ),
            ),
          ],
        ),
      ),

      bottomNavigationBar:
          const AppBottomNav(
        currentIndex: 2,
      ),
    );
  }
}