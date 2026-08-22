import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  RealtimeChannel? _sosChannel;

  final List<Map<String, dynamic>> _notifications = [];

  bool _isLoading = true;
  String? _errorMessage;

  // ============================================================
  // CURRENT LOCATION
  // ============================================================

  double? _latitude;
  double? _longitude;

  // ============================================================
  // LIVE WEATHER DATA
  // ============================================================

  double? _temperature;
  double? _humidity;
  double? _windSpeed;
  int? _weatherCode;

  String _weatherDescription = 'Unknown';

  DateTime? _weatherUpdatedAt;

  bool _weatherSafe = true;

  @override
  void initState() {
    super.initState();

    _initialize();
  }

  // ============================================================
  // INITIALIZE
  // ============================================================

  Future<void> _initialize() async {
    await _loadLiveConditions();
    _listenForSos();
  }

  // ============================================================
  // LOAD LIVE CONDITIONS
  // ============================================================

  Future<void> _loadLiveConditions() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _loadLiveWeather();

      if (!mounted) return;

      _buildDynamicNotifications();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('NOTIFICATION CONDITIONS ERROR: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load live conditions.';
      });
    }
  }

  // ============================================================
  // GET CURRENT GPS LOCATION
  // ============================================================

  Future<Position> _getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Location permission was denied.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission is permanently denied. '
        'Enable it in device settings.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  // ============================================================
  // LOAD LIVE WEATHER FROM OPEN-METEO
  // ============================================================

  Future<void> _loadLiveWeather() async {
    final Position position = await _getCurrentLocation();

    _latitude = position.latitude;
    _longitude = position.longitude;

    final Uri url = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=${position.latitude}'
      '&longitude=${position.longitude}'
      '&current=temperature_2m,'
      'relative_humidity_2m,'
      'weather_code,'
      'wind_speed_10m'
      '&timezone=auto',
    );

    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception('Weather request failed: ${response.statusCode}');
    }

    final Map<String, dynamic> data = jsonDecode(response.body);

    final Map<String, dynamic> current = data['current'];

    _temperature = (current['temperature_2m'] as num?)?.toDouble();

    _humidity = (current['relative_humidity_2m'] as num?)?.toDouble();

    _windSpeed = (current['wind_speed_10m'] as num?)?.toDouble();

    _weatherCode = (current['weather_code'] as num?)?.toInt();

    _weatherDescription = _weatherCodeToDescription(_weatherCode);

    _weatherSafe = _isWeatherSafe(_weatherCode);

    _weatherUpdatedAt = DateTime.now();
  }

  // ============================================================
  // WEATHER CODE -> DESCRIPTION
  // ============================================================

  String _weatherCodeToDescription(int? code) {
    if (code == null) {
      return 'Unknown';
    }

    switch (code) {
      case 0:
        return 'Clear sky';

      case 1:
        return 'Mainly clear';

      case 2:
        return 'Partly cloudy';

      case 3:
        return 'Overcast';

      case 45:
      case 48:
        return 'Foggy';

      case 51:
      case 53:
      case 55:
      case 56:
      case 57:
        return 'Drizzle';

      case 61:
      case 63:
      case 65:
      case 66:
      case 67:
        return 'Rain';

      case 71:
      case 73:
      case 75:
      case 77:
        return 'Snow';

      case 80:
      case 81:
      case 82:
        return 'Rain showers';

      case 85:
      case 86:
        return 'Snow showers';

      case 95:
        return 'Thunderstorm';

      case 96:
      case 99:
        return 'Thunderstorm with hail';

      default:
        return 'Unknown';
    }
  }

  // ============================================================
  // DETERMINE WEATHER SAFETY
  // ============================================================

  bool _isWeatherSafe(int? code) {
    if (code == null) {
      return true;
    }

    // Thunderstorm
    if (code >= 95) {
      return false;
    }

    // Heavy rain
    if (code == 65 || code == 67 || code == 82) {
      return false;
    }

    // Snow
    if (code == 75 || code == 77 || code == 86) {
      return false;
    }

    return true;
  }

  // ============================================================
  // BUILD DYNAMIC NOTIFICATIONS
  // ============================================================

  void _buildDynamicNotifications() {
    final List<Map<String, dynamic>> dynamicNotifications = [];

    final DateTime now = DateTime.now();

    // ----------------------------------------------------------
    // WEATHER
    // ----------------------------------------------------------

    dynamicNotifications.add({
      'id': 'weather-live',
      'type': 'weather',
      'title': _weatherSafe ? 'Weather Update' : 'Weather Alert',
      'subtitle': _buildWeatherMessage(),
      'created_at': (_weatherUpdatedAt ?? now).toIso8601String(),
    });

    // ----------------------------------------------------------
    // SAFETY
    // ----------------------------------------------------------

    dynamicNotifications.add({
      'id': 'safety-live',
      'type': 'safety',
      'title': _weatherSafe ? 'Safety Status' : 'Safety Alert',
      'subtitle': _buildSafetyMessage(),
      'created_at': now.toIso8601String(),
    });

    // ----------------------------------------------------------
    // TRAVEL
    // ----------------------------------------------------------

    dynamicNotifications.add({
      'id': 'travel-live',
      'type': 'travel',
      'title': 'Travel Update',
      'subtitle': _buildTravelMessage(),
      'created_at': now.toIso8601String(),
    });

    // ----------------------------------------------------------
    // KEEP EXISTING LIVE SOS NOTIFICATIONS
    // ----------------------------------------------------------

    final existingSos = _notifications.where((notification) {
      final type = notification['type']?.toString();

      return type == 'sos';
    });

    dynamicNotifications.addAll(existingSos);

    dynamicNotifications.sort((a, b) {
      final DateTime aDate =
          _parseDate(a['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0);

      final DateTime bDate =
          _parseDate(b['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0);

      return bDate.compareTo(aDate);
    });

    if (!mounted) return;

    setState(() {
      _notifications
        ..clear()
        ..addAll(dynamicNotifications);
    });
  }

  // ============================================================
  // WEATHER MESSAGE
  // ============================================================

  String _buildWeatherMessage() {
    final List<String> values = [];

    if (_temperature != null) {
      values.add('${_temperature!.round()}°C');
    }

    values.add(_weatherDescription);

    if (_humidity != null) {
      values.add('Humidity ${_humidity!.round()}%');
    }

    if (_windSpeed != null) {
      values.add('Wind ${_windSpeed!.round()} km/h');
    }

    return values.join(' • ');
  }

  // ============================================================
  // SAFETY MESSAGE
  // ============================================================

  String _buildSafetyMessage() {
    if (_weatherSafe) {
      return 'Current weather conditions are '
          'suitable for travel at your location.';
    }

    return 'Current weather conditions may be '
        'unsafe for travel. Exercise caution.';
  }

  // ============================================================
  // TRAVEL MESSAGE
  // ============================================================

  String _buildTravelMessage() {
    if (_weatherSafe) {
      return 'No current weather-based travel '
          'warning was detected for your location.';
    }

    return 'Weather conditions may affect your '
        'journey. Consider delaying outdoor travel '
        'or choosing a safer route.';
  }

  // ============================================================
  // ONLINE SOS - SUPABASE REALTIME
  // ============================================================

  void _listenForSos() {
    debugPrint('STARTING SOS REALTIME LISTENER...');

    _sosChannel = _supabase
        .channel('sos-alerts-${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'sos_alerts',
          callback: (payload) {
            debugPrint(
              'SOS REALTIME EVENT RECEIVED: '
              '${payload.newRecord}',
            );

            final newSos = payload.newRecord;

            final String id =
                newSos['id']?.toString() ??
                DateTime.now().millisecondsSinceEpoch.toString();

            final Map<String, dynamic> notification = {
              'id': id,
              'type': 'sos',
              'title': 'SOS Emergency Alert',
              'subtitle':
                  'A tourist has triggered an emergency SOS alert nearby.',
              'created_at': DateTime.now().toIso8601String(),
            };

            if (!mounted) return;

            setState(() {
              final alreadyExists = _notifications.any(
                (item) => item['id']?.toString() == id,
              );

              if (!alreadyExists) {
                _notifications.insert(0, notification);
              }
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
  // PARSE DATE
  // ============================================================

  DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(value.toString());
  }

  // ============================================================
  // FORMAT TIME
  // ============================================================

  String _formatTime(dynamic value) {
    final DateTime? date = _parseDate(value);

    if (date == null) {
      return '';
    }

    final DateTime local = date.toLocal();

    final int hour = local.hour % 12 == 0 ? 12 : local.hour % 12;

    final String minute = local.minute.toString().padLeft(2, '0');

    final String suffix = local.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $suffix';
  }

  // ============================================================
  // TODAY CHECK
  // ============================================================

  bool _isToday(DateTime date) {
    final DateTime now = DateTime.now();

    final DateTime local = date.toLocal();

    return local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
  }

  // ============================================================
  // ICON
  // ============================================================

  IconData _iconForType(String type) {
    switch (type) {
      case 'sos':
        return Icons.emergency;

      case 'weather':
        return Icons.cloud;

      case 'safety':
        return _weatherSafe
            ? Icons.shield_outlined
            : Icons.warning_amber_rounded;

      case 'travel':
        return Icons.route;

      default:
        return Icons.notifications;
    }
  }

  // ============================================================
  // COLOR
  // ============================================================

  Color _colorForType(String type) {
    switch (type) {
      case 'sos':
        return AppColors.dangerRed;

      case 'weather':
        return _weatherSafe ? AppColors.infoBlue : AppColors.dangerRed;

      case 'safety':
        return _weatherSafe ? AppColors.primaryGreen : AppColors.dangerRed;

      case 'travel':
        return _weatherSafe ? AppColors.primaryGreen : AppColors.warningOrange;

      default:
        return AppColors.infoBlue;
    }
  }

  // ============================================================
  // BACKGROUND
  // ============================================================

  Color _backgroundForType(String type) {
    switch (type) {
      case 'sos':
        return AppColors.dangerBgLight;

      case 'weather':
        return _weatherSafe ? AppColors.infoBgLight : AppColors.dangerBgLight;

      case 'safety':
        return _weatherSafe ? AppColors.lightGreenBg : AppColors.dangerBgLight;

      case 'travel':
        return _weatherSafe ? AppColors.lightGreenBg : AppColors.warningBgLight;

      default:
        return Colors.grey.shade100;
    }
  }

  // ============================================================
  // SOS DIALOG
  // ============================================================

  void _showSosDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.emergency, color: AppColors.dangerRed),
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
            'A tourist has triggered an emergency SOS alert nearby.',
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
  // EMPTY STATE
  // ============================================================

  Widget _emptyState() {
    return RefreshIndicator(
      onRefresh: _loadLiveConditions,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 100),
        children: const [
          Icon(Icons.notifications_none, size: 64, color: AppColors.textGrey),
          SizedBox(height: 16),
          Center(
            child: Text(
              'No notifications',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(height: 8),
          Center(
            child: Text(
              'Live safety and travel updates will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textGrey),
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
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> todayNotifications = _notifications.where((
      notification,
    ) {
      final date = _parseDate(notification['created_at']);

      return date != null && _isToday(date);
    }).toList();

    final List<Map<String, dynamic>> earlierNotifications = _notifications
        .where((notification) {
          final date = _parseDate(notification['created_at']);

          return date == null || !_isToday(date);
        })
        .toList();

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadLiveConditions,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? _emptyState()
          : RefreshIndicator(
              onRefresh: _loadLiveConditions,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  // ==========================================
                  // TODAY
                  // ==========================================

                  if (todayNotifications.isNotEmpty) ...[
                    const Text(
                      'Today',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textGrey,
                      ),
                    ),

                    const SizedBox(height: 10),

                    ...todayNotifications.map((notification) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildNotificationCard(notification),
                      );
                    }),
                  ],

                  // ==========================================
                  // EARLIER
                  // ==========================================
                  if (earlierNotifications.isNotEmpty) ...[
                    const SizedBox(height: 10),

                    const Text(
                      'Earlier',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textGrey,
                      ),
                    ),

                    const SizedBox(height: 10),

                    ...earlierNotifications.map((notification) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildNotificationCard(notification),
                      );
                    }),
                  ],
                ],
              ),
            ),
    );
  }

  // ============================================================
  // NOTIFICATION CARD
  // ============================================================

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final String type = notification['type']?.toString() ?? 'info';

    final String title = notification['title']?.toString() ?? 'Notification';

    final String subtitle = notification['subtitle']?.toString() ?? '';

    return Dismissible(
      key: ValueKey(notification['id'] ?? notification.hashCode),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        setState(() {
          _notifications.remove(notification);
        });
      },
      background: Container(
        decoration: BoxDecoration(
          color: AppColors.dangerRed,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: _notifCard(
        icon: _iconForType(type),
        color: _colorForType(type),
        bg: _backgroundForType(type),
        title: title,
        subtitle: subtitle,
        time: _formatTime(notification['created_at']),
      ),
    );
  }

  // ============================================================
  // CARD
  // ============================================================

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
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 4),

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

          const SizedBox(width: 8),

          Text(
            time,
            style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CLEANUP
  // ============================================================

  @override
  void dispose() {
    if (_sosChannel != null) {
      _supabase.removeChannel(_sosChannel!);
    }

    super.dispose();
  }
}
