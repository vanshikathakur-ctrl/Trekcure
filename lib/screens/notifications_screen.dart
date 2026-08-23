import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/mesh_service.dart';
import '../theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState
    extends State<NotificationsScreen> {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  final MeshService _meshService =
      MeshService.instance;

  static final Set<String>
      _dismissedNotificationIds = {};

  RealtimeChannel? _sosChannel;

  StreamSubscription<Map<String, dynamic>>?
      _meshSosSubscription;

  final List<Map<String, dynamic>>
      _notifications = [];

  bool _isLoading = true;

  String _currentArea = 'your trail';

  @override
  void initState() {
    super.initState();

    _initialize();
  }

  Future<void> _initialize() async {
    _listenForMeshSos();

    await _loadLiveConditions();

    _listenForSos();
  }

  // ============================================================
  // OFFLINE MESH SOS LISTENER
  // ============================================================

  void _listenForMeshSos() {
    _meshSosSubscription =
        _meshService.sosStream.listen(
      (data) {
        if (!mounted) return;

        final String type =
            data['type']
                    ?.toString()
                    .toUpperCase() ??
                '';

        if (type == 'SOS_CANCELLED') {
          _handleOfflineSosCancelled(data);
          return;
        }

        if (type == 'SOS') {
          _handleOfflineSos(data);
        }
      },
      onError: (error) {
        debugPrint(
          'MESH SOS STREAM ERROR: $error',
        );
      },
    );
  }

  // ============================================================
  // HANDLE OFFLINE SOS
  // ============================================================

  void _handleOfflineSos(
    Map<String, dynamic> data,
  ) {
    if (!mounted) return;

    final String sosId =
        data['sosId']?.toString() ?? '';

    if (sosId.isEmpty) {
      debugPrint(
        'OFFLINE SOS IGNORED: Missing SOS ID',
      );
      return;
    }

    final String senderName =
        data['senderName']?.toString() ??
            'Unknown user';

    final String location =
        data['location']?.toString() ??
            'Location unavailable';

    final String message =
        data['message']?.toString() ??
            'Emergency SOS received';

    final String notificationId =
        'offline_sos_$sosId';

    if (_dismissedNotificationIds
        .contains(notificationId)) {
      return;
    }

    final bool alreadyExists =
        _notifications.any(
      (notification) =>
          notification['id'] == notificationId,
    );

    if (alreadyExists) {
      return;
    }

    final Map<String, dynamic> notification = {
      'id': notificationId,
      'sosId': sosId,
      'type': 'offline_sos',
      'title': '📡 OFFLINE SOS ALERT',
      'subtitle':
          '$senderName needs emergency assistance near $location. '
          'Message: $message',
      'created_at':
          DateTime.now().toIso8601String(),
      'senderName': senderName,
      'location': location,
    };

    setState(() {
      _notifications.insert(
        0,
        notification,
      );
    });

    _showOfflineSosDialog(
      senderName: senderName,
      location: location,
    );
  }

  // ============================================================
  // HANDLE OFFLINE SOS CANCELLATION
  // ============================================================

  void _handleOfflineSosCancelled(
    Map<String, dynamic> data,
  ) {
    if (!mounted) return;

    final String sosId =
        data['sosId']?.toString() ?? '';

    if (sosId.isEmpty) {
      debugPrint(
        'OFFLINE SOS CANCELLATION IGNORED: Missing SOS ID',
      );
      return;
    }

    final String senderName =
        data['senderName']?.toString() ??
            'Unknown TrekCure User';

    final String originalNotificationId =
        'offline_sos_$sosId';

    final String cancellationNotificationId =
        'offline_sos_cancelled_$sosId';

    if (_dismissedNotificationIds
        .contains(cancellationNotificationId)) {
      return;
    }

    final bool cancellationAlreadyExists =
        _notifications.any(
      (notification) =>
          notification['id'] ==
              cancellationNotificationId,
    );

    if (cancellationAlreadyExists) {
      return;
    }

    // Remove the original SOS notification.
    final Map<String, dynamic>? originalSos =
        _notifications.cast<Map<String, dynamic>?>()
            .firstWhere(
      (notification) =>
          notification?['id'] ==
              originalNotificationId,
      orElse: () => null,
    );

    final String location =
        originalSos?['location']
                ?.toString() ??
            'Location unavailable';

    setState(() {
      _notifications.removeWhere(
        (notification) =>
            notification['id'] ==
            originalNotificationId,
      );

      _notifications.insert(
        0,
        {
          'id': cancellationNotificationId,
          'sosId': sosId,
          'type': 'offline_sos_cancelled',
          'title':
              '📡 OFFLINE SOS CANCELLED',
          'subtitle':
              '$senderName has cancelled the offline emergency SOS. '
              'Last known location: $location.',
          'created_at':
              DateTime.now().toIso8601String(),
          'senderName': senderName,
          'location': location,
        },
      );
    });

    _showOfflineSosCancelledDialog(
      senderName: senderName,
      location: location,
    );
  }

  // ============================================================
  // LOAD LIVE DATA
  // ============================================================

  Future<void> _loadLiveConditions() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final Position position =
          await _getCurrentLocation();

      await _fetchReverseGeocode(
        position.latitude,
        position.longitude,
      );

      final Uri url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=${position.latitude}'
        '&longitude=${position.longitude}'
        '&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m'
        '&timezone=auto',
      );

      final response = await http
          .get(url)
          .timeout(
            const Duration(seconds: 6),
          );

      double temp = 28.0;
      double wind = 12.0;
      int weatherCode = 0;

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body);

        final Map<String, dynamic> current =
            data['current'];

        temp =
            (current['temperature_2m'] as num)
                .toDouble();

        wind =
            (current['wind_speed_10m'] as num)
                .toDouble();

        weatherCode =
            (current['weather_code'] as num)
                .toInt();
      }

      final Random random = Random(
        (position.latitude * 100).toInt() +
            (position.longitude * 100).toInt(),
      );

      final int crowdPercentage =
          (20 +
                  random.nextDouble() *
                      70)
              .round();

      if (!mounted) return;

      _generateDynamicNotificationList(
        temp: temp,
        wind: wind,
        weatherCode: weatherCode,
        crowdPercentage: crowdPercentage,
      );

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint(
        'Notification generation error: $e',
      );

      if (!mounted) return;

      _generateDynamicNotificationList(
        temp: 28.0,
        wind: 12.0,
        weatherCode: 2,
        crowdPercentage: 65,
      );

      setState(() {
        _isLoading = false;
      });
    }
  }

  // ============================================================
  // REVERSE GEOCODE
  // ============================================================

  Future<void> _fetchReverseGeocode(
    double lat,
    double lon,
  ) async {
    try {
      final Uri geoUrl = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=$lat'
        '&lon=$lon'
        '&format=jsonv2',
      );

      final response = await http
          .get(
            geoUrl,
            headers: {
              'User-Agent':
                  'TrekCureApp/1.0',
            },
          )
          .timeout(
            const Duration(seconds: 4),
          );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body);

        final Map<String, dynamic>? address =
            data['address'];

        if (address != null) {
          _currentArea =
              address['suburb'] ??
                  address['neighbourhood'] ??
                  address['city'] ??
                  address['town'] ??
                  'Central Trail';
        }
      }
    } catch (_) {}
  }

  Future<Position> _getCurrentLocation() async {
    final bool serviceEnabled =
        await Geolocator
            .isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception(
        'Location services disabled.',
      );
    }

    LocationPermission permission =
        await Geolocator.checkPermission();

    if (permission ==
        LocationPermission.denied) {
      permission =
          await Geolocator.requestPermission();
    }

    if (permission ==
            LocationPermission.denied ||
        permission ==
            LocationPermission.deniedForever) {
      throw Exception(
        'Location permission denied.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings:
          const LocationSettings(
        accuracy:
            LocationAccuracy.medium,
      ),
    );
  }

  // ============================================================
  // DYNAMIC NOTIFICATIONS
  // ============================================================

  void _generateDynamicNotificationList({
    required double temp,
    required double wind,
    required int weatherCode,
    required int crowdPercentage,
  }) {
    final DateTime now = DateTime.now();

    final List<Map<String, dynamic>>
        items = [];

    if (crowdPercentage > 50 &&
        !_dismissedNotificationIds
            .contains('crowd-alert')) {
      items.add({
        'id': 'crowd-alert',
        'type': 'crowd',
        'title':
            'High Footfall Warning',
        'subtitle':
            'Dense tourist surge detected near $_currentArea. Bottlenecks likely.',
        'created_at': now
            .subtract(
              const Duration(minutes: 8),
            )
            .toIso8601String(),
      });
    }

    final String weatherDesc =
        _weatherCodeToDescription(
      weatherCode,
    );

    final bool isSevere =
        weatherCode >= 51 ||
            wind > 25;

    if (!_dismissedNotificationIds
        .contains('weather-alert')) {
      items.add({
        'id': 'weather-alert',
        'type': 'weather',
        'title': isSevere
            ? 'Adverse Weather Advisory'
            : 'Live Weather Update',
        'subtitle':
            '${temp.round()}°C • $weatherDesc • '
            'Wind ${wind.round()} km/h recorded in $_currentArea.',
        'created_at': now
            .subtract(
              const Duration(minutes: 24),
            )
            .toIso8601String(),
      });
    }

    if (!_dismissedNotificationIds
        .contains('mesh-status')) {
      items.add({
        'id': 'mesh-status',
        'type': 'mesh',
        'title':
            'Offline Mesh Network Active',
        'subtitle':
            'Nearby emergency relay connections are available for offline SOS communication.',
        'created_at': now
            .subtract(
              const Duration(
                hours: 1,
                minutes: 15,
              ),
            )
            .toIso8601String(),
      });
    }

    final existingSos =
        _notifications.where(
      (notification) {
        final String type =
            notification['type']
                    ?.toString() ??
                '';

        return (type == 'sos' ||
                type == 'sos_cancelled' ||
                type == 'offline_sos' ||
                type ==
                    'offline_sos_cancelled') &&
            !_dismissedNotificationIds
                .contains(
              notification['id']
                  ?.toString(),
            );
      },
    );

    items.addAll(existingSos);

    items.sort((a, b) {
      final DateTime aDate =
          DateTime.tryParse(
                a['created_at']
                        ?.toString() ??
                    '',
              ) ??
              now;

      final DateTime bDate =
          DateTime.tryParse(
                b['created_at']
                        ?.toString() ??
                    '',
              ) ??
              now;

      return bDate.compareTo(aDate);
    });

    _notifications.clear();

    _notifications.addAll(items);
  }

  String _weatherCodeToDescription(
    int code,
  ) {
    if (code == 0) {
      return 'Clear Sky';
    }

    if (code <= 3) {
      return 'Partly Cloudy';
    }

    if (code <= 48) {
      return 'Foggy';
    }

    if (code <= 67) {
      return 'Rain';
    }

    if (code <= 77) {
      return 'Snow';
    }

    if (code >= 95) {
      return 'Thunderstorm';
    }

    return 'Overcast';
  }

  // ============================================================
  // SUPABASE REALTIME SOS LISTENER
  // ============================================================

  void _listenForSos() {
    _sosChannel = _supabase
        .channel(
          'sos-alerts-channel',
        )
        .onPostgresChanges(
          event:
              PostgresChangeEvent.insert,
          schema: 'public',
          table: 'sos_alerts',
          callback: (payload) {
            final newSos =
                payload.newRecord;

            final String sosId =
                newSos['id']
                        ?.toString() ??
                    '';

            if (sosId.isEmpty) {
              return;
            }

            final String notificationId =
                'online_sos_$sosId';

            if (_dismissedNotificationIds
                .contains(notificationId)) {
              return;
            }

            if (!mounted) return;

            final bool alreadyExists =
                _notifications.any(
              (notification) =>
                  notification['id'] ==
                      notificationId,
            );

            if (alreadyExists) {
              return;
            }

            setState(() {
              _notifications.insert(
                0,
                {
                  'id': notificationId,
                  'sosId': sosId,
                  'type': 'sos',
                  'title':
                      '🚨 SOS EMERGENCY ALERT',
                  'subtitle':
                      'A tourist triggered an emergency distress beacon near $_currentArea!',
                  'created_at':
                      newSos['created_at']
                              ?.toString() ??
                          DateTime.now()
                              .toIso8601String(),
                },
              );
            });
          },
        )
        .onPostgresChanges(
          event:
              PostgresChangeEvent.update,
          schema: 'public',
          table: 'sos_alerts',
          callback: (payload) {
            final updatedSos =
                payload.newRecord;

            final String sosStatus =
                updatedSos['status']
                        ?.toString()
                        .toLowerCase() ??
                    '';

            if (sosStatus != 'cancelled') {
              return;
            }

            final String sosId =
                updatedSos['id']
                        ?.toString() ??
                    '';

            if (sosId.isEmpty) {
              return;
            }

            final String originalNotificationId =
                'online_sos_$sosId';

            final String cancellationNotificationId =
                'online_sos_cancelled_$sosId';

            if (_dismissedNotificationIds
                .contains(
                  cancellationNotificationId,
                )) {
              return;
            }

            if (!mounted) return;

            final bool alreadyExists =
                _notifications.any(
              (notification) =>
                  notification['id'] ==
                      cancellationNotificationId,
            );

            if (alreadyExists) {
              return;
            }

            setState(() {
              _notifications.removeWhere(
                (notification) =>
                    notification['id'] ==
                    originalNotificationId,
              );

              _notifications.insert(
                0,
                {
                  'id':
                      cancellationNotificationId,
                  'sosId': sosId,
                  'type':
                      'sos_cancelled',
                  'title':
                      '✅ SOS CANCELLED',
                  'subtitle':
                      'The emergency distress signal has been cancelled. '
                          'The tourist is no longer requesting emergency assistance.',
                  'created_at':
                      updatedSos['updated_at']
                              ?.toString() ??
                          DateTime.now()
                              .toIso8601String(),
                },
              );
            });

            _showSosCancelledDialog();
          },
        )
        .subscribe();
  }

  // ============================================================
  // ONLINE SOS CANCELLED DIALOG
  // ============================================================

  void _showSosCancelledDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
        title: const Row(
          children: [
            Icon(
              Icons.check_circle,
              color:
                  AppColors.primaryGreen,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'SOS CANCELLED',
                style: TextStyle(
                  color:
                      AppColors.primaryGreen,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'The tourist has cancelled the emergency distress signal. '
          'No further emergency assistance is currently requested.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context),
            child:
                const Text(
              'Acknowledge',
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // OFFLINE SOS DIALOG
  // ============================================================

  void _showOfflineSosDialog({
    required String senderName,
    required String location,
  }) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
        title: const Row(
          children: [
            Icon(
              Icons.wifi_off,
              color:
                  AppColors.dangerRed,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'OFFLINE SOS RECEIVED',
                style: TextStyle(
                  color:
                      AppColors.dangerRed,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          '$senderName has sent an emergency SOS through the offline mesh network.\n\n'
          'Location: $location',
        ),
        actions: [
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context),
            style:
                ElevatedButton.styleFrom(
              backgroundColor:
                  AppColors.dangerRed,
            ),
            child:
                const Text(
              'Acknowledge',
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // OFFLINE SOS CANCELLED DIALOG
  // ============================================================

  void _showOfflineSosCancelledDialog({
    required String senderName,
    required String location,
  }) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
        title: const Row(
          children: [
            Icon(
              Icons.check_circle,
              color:
                  AppColors.primaryGreen,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'OFFLINE SOS CANCELLED',
                style: TextStyle(
                  color:
                      AppColors.primaryGreen,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          '$senderName has cancelled the offline SOS.\n\n'
          'Last known location: $location',
        ),
        actions: [
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context),
            child:
                const Text(
              'Acknowledge',
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  bool _isToday(
    DateTime date,
  ) {
    final DateTime now =
        DateTime.now();

    final DateTime local =
        date.toLocal();

    return local.year ==
            now.year &&
        local.month ==
            now.month &&
        local.day ==
            now.day;
  }

  String _formatTime(
    dynamic value,
  ) {
    if (value == null) return '';

    final DateTime? date =
        DateTime.tryParse(
      value.toString(),
    );

    if (date == null) return '';

    final DateTime local =
        date.toLocal();

    final int hour =
        local.hour % 12 == 0
            ? 12
            : local.hour % 12;

    final String minute =
        local.minute
            .toString()
            .padLeft(2, '0');

    final String suffix =
        local.hour >= 12
            ? 'PM'
            : 'AM';

    return '$hour:$minute $suffix';
  }

  IconData _iconForType(
    String type,
  ) {
    switch (type) {
      case 'sos':
        return Icons.emergency;

      case 'sos_cancelled':
        return Icons.check_circle;

      case 'offline_sos':
        return Icons.wifi_off;

      case 'offline_sos_cancelled':
        return Icons.check_circle;

      case 'crowd':
        return Icons.groups;

      case 'weather':
        return Icons.cloud;

      case 'mesh':
        return Icons.sensors;

      default:
        return Icons.notifications;
    }
  }

  Color _colorForType(
    String type,
  ) {
    switch (type) {
      case 'sos':
      case 'offline_sos':
        return AppColors.dangerRed;

      case 'sos_cancelled':
      case 'offline_sos_cancelled':
        return AppColors.primaryGreen;

      case 'crowd':
        return AppColors.warningOrange;

      case 'weather':
        return AppColors.infoBlue;

      case 'mesh':
        return AppColors.primaryGreen;

      default:
        return AppColors.infoBlue;
    }
  }

  Color _backgroundForType(
    String type,
  ) {
    switch (type) {
      case 'sos':
      case 'offline_sos':
        return AppColors.dangerBgLight;

      case 'sos_cancelled':
      case 'offline_sos_cancelled':
        return AppColors.lightGreenBg;

      case 'crowd':
        return AppColors.warningBgLight;

      case 'weather':
        return AppColors.infoBgLight;

      case 'mesh':
        return AppColors.lightGreenBg;

      default:
        return Colors.grey.shade100;
    }
  }

  @override
  void dispose() {
    _meshSosSubscription?.cancel();

    if (_sosChannel != null) {
      _supabase.removeChannel(
        _sosChannel!,
      );
    }

    super.dispose();
  }

  Widget _emptyState() {
    return RefreshIndicator(
      onRefresh:
          _loadLiveConditions,
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 100,
        ),
        children: const [
          Icon(
            Icons.notifications_none,
            size: 64,
            color:
                AppColors.textGrey,
          ),
          SizedBox(height: 16),
          Center(
            child: Text(
              'No notifications',
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: 8),
          Center(
            child: Text(
              'All safety and travel updates have been cleared.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color:
                    AppColors.textGrey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final List<Map<String, dynamic>>
        todayNotifications =
        _notifications.where(
      (notification) {
        final DateTime? date =
            DateTime.tryParse(
          notification['created_at']
                  ?.toString() ??
              '',
        );

        return date != null &&
            _isToday(date);
      },
    ).toList();

    final List<Map<String, dynamic>>
        earlierNotifications =
        _notifications.where(
      (notification) {
        final DateTime? date =
            DateTime.tryParse(
          notification['created_at']
                  ?.toString() ??
              '',
        );

        return date == null ||
            !_isToday(date);
      },
    ).toList();

    return Scaffold(
      appBar: AppBar(
        leading:
            const BackButton(),
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontWeight:
                FontWeight.bold,
            fontSize: 17,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed:
                _loadLiveConditions,
            icon:
                const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : _notifications.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  onRefresh:
                      _loadLiveConditions,
                  child: ListView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    padding:
                        const EdgeInsets.all(16),
                    children: [
                      if (todayNotifications
                          .isNotEmpty) ...[
                        const Text(
                          'Today',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.bold,
                            fontSize: 14,
                            color:
                                AppColors.textGrey,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...todayNotifications.map(
                          (notification) =>
                              Padding(
                            padding:
                                const EdgeInsets.only(
                              bottom: 12,
                            ),
                            child:
                                _buildNotificationCard(
                              notification,
                            ),
                          ),
                        ),
                      ],
                      if (earlierNotifications
                          .isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Earlier',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.bold,
                            fontSize: 14,
                            color:
                                AppColors.textGrey,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...earlierNotifications.map(
                          (notification) =>
                              Padding(
                            padding:
                                const EdgeInsets.only(
                              bottom: 12,
                            ),
                            child:
                                _buildNotificationCard(
                              notification,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildNotificationCard(
    Map<String, dynamic> notification,
  ) {
    final String type =
        notification['type']
                ?.toString() ??
            'info';

    final String title =
        notification['title']
                ?.toString() ??
            'Notification';

    final String subtitle =
        notification['subtitle']
                ?.toString() ??
            '';

    final String id =
        notification['id']
                ?.toString() ??
            '';

    return Dismissible(
      key: ValueKey(
        id.isNotEmpty
            ? id
            : notification.hashCode,
      ),
      direction:
          DismissDirection.endToStart,
      onDismissed: (_) {
        setState(() {
          if (id.isNotEmpty) {
            _dismissedNotificationIds.add(id);
          }

          _notifications.remove(notification);
        });
      },
      background: Container(
        decoration: BoxDecoration(
          color:
              AppColors.dangerRed,
          borderRadius:
              BorderRadius.circular(16),
        ),
        alignment:
            Alignment.centerRight,
        padding:
            const EdgeInsets.only(right: 20),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      child: AppCard(
        color:
            _backgroundForType(type),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(
            vertical: 4,
            horizontal: 2,
          ),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration:
                    BoxDecoration(
                  color:
                      _colorForType(type)
                          .withOpacity(0.14),
                  shape:
                      BoxShape.circle,
                ),
                child: Icon(
                  _iconForType(type),
                  color:
                      _colorForType(type),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style:
                          const TextStyle(
                        fontSize: 13,
                        color:
                            AppColors.textGrey,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatTime(
                  notification['created_at'],
                ),
                style:
                    const TextStyle(
                  fontSize: 12,
                  color:
                      AppColors.textGrey,
                  fontWeight:
                      FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}