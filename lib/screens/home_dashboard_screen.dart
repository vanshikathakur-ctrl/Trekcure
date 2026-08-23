import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/mesh_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';
import 'AI_screen.dart';
import 'map_crowd_screen.dart';
import 'notifications_screen.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() =>
      _HomeDashboardScreenState();
}

class _HomeDashboardScreenState
    extends State<HomeDashboardScreen> {
  String _userName = 'User';

  // ============================================================
  // DYNAMIC LOCATION & TRAVEL ALERT
  // ============================================================

  String _userLocationText = 'Locating...';

  String _nearbyAlertLocation = 'your current trail';

  // ============================================================
  // NOTIFICATION BADGE
  // ============================================================

  int _unreadNotifications = 2;

  // ============================================================
  // WEATHER STATE
  // ============================================================

  double? _temperature;

  double? _humidity;

  double? _windSpeed;

  String _weatherCondition = 'Loading...';

  bool _weatherLoading = true;

  // ============================================================
  // CROWD STATE
  // ============================================================

  String _crowdLevel = 'Loading...';

  int _crowdPeopleCount = 0;

  Color _crowdColor = AppColors.warningOrange;

  bool _isCrowdLoading = true;

  // ============================================================
  // OFFLINE MESH STATE
  // ============================================================

  final MeshService _meshService =
      MeshService.instance;

  int _nearbyMeshNodes = 0;

  bool _meshRelayActive = false;

  StreamSubscription<int>? _meshNodeSubscription;

  StreamSubscription<Map<String, dynamic>>?
      _sosSubscription;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadUserName();

    _loadDashboardData();

    _initializeMeshStatus();

    _initializeSosListener();
  }

  // ============================================================
  // INITIALIZE MESH STATUS
  // ============================================================

  void _initializeMeshStatus() {
    if (mounted) {
      setState(() {
        _nearbyMeshNodes =
            _meshService.nearbyNodeCount;

        _meshRelayActive =
            _meshService.isRunning;
      });
    }

    _meshNodeSubscription =
        _meshService.nodeCountStream.listen(
      (nodeCount) {
        if (!mounted) return;

        setState(() {
          _nearbyMeshNodes = nodeCount;

          _meshRelayActive =
              _meshService.isRunning;
        });

        debugPrint('');
        debugPrint('==============================');
        debugPrint('DASHBOARD MESH UPDATED');
        debugPrint('Nearby nodes: $nodeCount');
        debugPrint(
          'Mesh running: ${_meshService.isRunning}',
        );
        debugPrint('==============================');
        debugPrint('');
      },
      onError: (error) {
        debugPrint(
          'Mesh status stream error: $error',
        );
      },
    );
  }

  // ============================================================
  // INITIALIZE SOS LISTENER
  // ============================================================

  void _initializeSosListener() {
    _sosSubscription =
        _meshService.sosStream.listen(
      (sosData) {
        if (!mounted) return;

        final senderName =
            sosData['senderName']?.toString() ??
                'Unknown device';

        final payload =
            sosData['payload']?.toString() ??
                'SOS';

        debugPrint('');
        debugPrint('==============================');
        debugPrint('DASHBOARD RECEIVED MESH SOS');
        debugPrint('From: $senderName');
        debugPrint('Payload: $payload');
        debugPrint('==============================');
        debugPrint('');

        _showIncomingSosDialog(
          senderName: senderName,
          payload: payload,
        );
      },
      onError: (error) {
        debugPrint(
          'SOS stream error: $error',
        );
      },
    );
  }

  // ============================================================
  // SHOW INCOMING SOS DIALOG
  // ============================================================

  void _showIncomingSosDialog({
    required String senderName,
    required String payload,
  }) {
    if (!mounted) return;

    String message = payload;
    String latitude = '';
    String longitude = '';

    final parts = payload.split('|');

    if (parts.isNotEmpty &&
        parts.first.toUpperCase() == 'SOS') {
      if (parts.length > 1 &&
          parts[1].trim().isNotEmpty) {
        message = parts[1];
      } else {
        message = 'Emergency SOS received';
      }

      if (parts.length > 2) {
        latitude = parts[2];
      }

      if (parts.length > 3) {
        longitude = parts[3];
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.sos,
                color: AppColors.dangerRed,
                size: 32,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'SOS RECEIVED',
                  style: TextStyle(
                    color: AppColors.dangerRed,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'Emergency signal received from:',
                style: TextStyle(
                  color: AppColors.textGrey,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                senderName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppColors.textDark,
                ),
              ),

              const SizedBox(height: 16),

              Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textDark,
                ),
              ),

              if (latitude.isNotEmpty &&
                  longitude.isNotEmpty) ...[
                const SizedBox(height: 16),

                Text(
                  'Location:',
                  style: TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  '$latitude, $longitude',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'DISMISS',
                style: TextStyle(
                  color: AppColors.textGrey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    AppColors.dangerRed,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'ACKNOWLEDGE',
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // LOAD USER PROFILE
  // ============================================================

  Future<void> _loadUserName() async {
    final supabase =
        Supabase.instance.client;

    final user =
        supabase.auth.currentUser;

    if (user == null) return;

    try {
      final profile = await supabase
          .from('profiles')
          .select('full_name')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        _userName =
            profile?['full_name'] ?? 'User';
      });
    } catch (e) {
      debugPrint(
        'Could not load user name: $e',
      );
    }
  }

  // ============================================================
  // UNIFIED DASHBOARD DATA LOADER
  // ============================================================

  Future<void> _loadDashboardData() async {
    if (!mounted) return;

    setState(() {
      _weatherLoading = true;

      _isCrowdLoading = true;
    });

    try {
      final bool serviceEnabled =
          await Geolocator
              .isLocationServiceEnabled();

      if (!serviceEnabled) {
        _setFallbackMetrics();
        return;
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission ==
          LocationPermission.denied) {
        permission =
            await Geolocator
                .requestPermission();
      }

      if (permission ==
              LocationPermission.denied ||
          permission ==
              LocationPermission.deniedForever) {
        _setFallbackMetrics();
        return;
      }

      final Position position =
          await Geolocator
              .getCurrentPosition(
        locationSettings:
            const LocationSettings(
          accuracy:
              LocationAccuracy.medium,
        ),
      );

      _fetchReverseGeocodeLocation(
        position.latitude,
        position.longitude,
      );

      final Random random = Random(
        (position.latitude * 100)
                .toInt() +
            (position.longitude * 100)
                .toInt(),
      );

      final double avgDensity =
          0.2 +
              (random.nextDouble() * 0.7);

      final int percentage =
          (avgDensity * 100).round();

      final int estimatedPeople =
          (avgDensity * 350).round();

      String crowdLevel;

      Color crowdColor;

      if (percentage <= 30) {
        crowdLevel = 'Low';

        crowdColor = Colors.green;
      } else if (percentage <= 70) {
        crowdLevel = 'Moderate';

        crowdColor =
            AppColors.warningOrange;
      } else {
        crowdLevel = 'High';

        crowdColor =
            AppColors.dangerRed;
      }

      final Uri weatherUrl =
          Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=${position.latitude}'
        '&longitude=${position.longitude}'
        '&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m'
        '&timezone=auto',
      );

      final response =
          await http
              .get(weatherUrl)
              .timeout(
                const Duration(
                  seconds: 6,
                ),
              );

      if (response.statusCode == 200) {
        final Map<String, dynamic>
            data =
            jsonDecode(response.body);

        final Map<String, dynamic>
            current =
            data['current'];

        final double temp =
            (current['temperature_2m']
                    as num)
                .toDouble();

        final double hum =
            (current[
                        'relative_humidity_2m']
                    as num)
                .toDouble();

        final double wind =
            (current['wind_speed_10m']
                    as num)
                .toDouble();

        final int weatherCode =
            (current['weather_code']
                    as num)
                .toInt();

        if (!mounted) return;

        setState(() {
          _temperature = temp;

          _humidity = hum;

          _windSpeed = wind;

          _weatherCondition =
              _weatherDescription(
            weatherCode,
          );

          _weatherLoading = false;

          _crowdLevel =
              crowdLevel;

          _crowdPeopleCount =
              estimatedPeople;

          _crowdColor =
              crowdColor;

          _isCrowdLoading =
              false;

          _nearbyMeshNodes =
              _meshService.nearbyNodeCount;

          _meshRelayActive =
              _meshService.isRunning;
        });
      } else {
        _setFallbackMetrics();
      }
    } catch (e) {
      debugPrint(
        'Dashboard data load error: $e',
      );

      _setFallbackMetrics();
    }
  }

  // ============================================================
  // REVERSE GEOCODING
  // ============================================================

  Future<void>
      _fetchReverseGeocodeLocation(
    double lat,
    double lon,
  ) async {
    try {
      final Uri geoUrl =
          Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=$lat'
        '&lon=$lon'
        '&format=jsonv2',
      );

      final response =
          await http
              .get(
                geoUrl,
                headers: {
                  'User-Agent':
                      'TrekCureApp/1.0',
                },
              )
              .timeout(
                const Duration(
                  seconds: 4,
                ),
              );

      if (response.statusCode == 200) {
        final Map<String, dynamic>
            data =
            jsonDecode(response.body);

        final Map<String, dynamic>?
            address =
            data['address'];

        if (address != null) {
          final String localAlertSpot =
              address['tourism'] ??
                  address['historic'] ??
                  address['suburb'] ??
                  address[
                      'neighbourhood'] ??
                  address['road'] ??
                  address['residential'] ??
                  address[
                      'city_district'] ??
                  'Central Trail';

          final String cityOrArea =
              address['city'] ??
                  address['town'] ??
                  address['village'] ??
                  address['suburb'] ??
                  address['county'] ??
                  'Nearby Area';

          final String country =
              address['country'] ??
                  'India';

          if (!mounted) return;

          setState(() {
            _userLocationText =
                '$cityOrArea, $country';

            _nearbyAlertLocation =
                localAlertSpot;
          });

          return;
        }
      }
    } catch (e) {
      debugPrint(
        'Reverse geocode error: $e',
      );
    }

    if (!mounted) return;

    setState(() {
      _userLocationText =
          'Thane, India';

      _nearbyAlertLocation =
          'Central Trail';
    });
  }

  // ============================================================
  // FALLBACK DATA
  // ============================================================

  void _setFallbackMetrics() {
    if (!mounted) return;

    setState(() {
      _userLocationText =
          'Thane, India';

      _nearbyAlertLocation =
          'Central Trail';

      _temperature = 28.0;

      _humidity = 75.0;

      _windSpeed = 12.0;

      _weatherCondition =
          'Partly cloudy';

      _weatherLoading = false;

      _crowdLevel = 'Moderate';

      _crowdPeopleCount = 180;

      _crowdColor =
          AppColors.warningOrange;

      _isCrowdLoading = false;

      _nearbyMeshNodes =
          _meshService.nearbyNodeCount;

      _meshRelayActive =
          _meshService.isRunning;
    });
  }

  // ============================================================
  // WEATHER HELPERS
  // ============================================================

  String _weatherDescription(
    int code,
  ) {
    if (code == 0) return 'Clear sky';

    if (code == 1) return 'Mainly clear';

    if (code == 2) return 'Partly cloudy';

    if (code == 3) return 'Overcast';

    if (code == 45 ||
        code == 48) {
      return 'Foggy';
    }

    if (code >= 51 &&
        code <= 57) {
      return 'Drizzle';
    }

    if (code >= 61 &&
        code <= 67) {
      return 'Rain';
    }

    if (code >= 71 &&
        code <= 77) {
      return 'Snow';
    }

    if (code >= 80 &&
        code <= 82) {
      return 'Rain showers';
    }

    if (code >= 95) {
      return 'Thunderstorm';
    }

    return 'Overcast';
  }

  IconData _weatherIcon() {
    final condition =
        _weatherCondition.toLowerCase();

    if (condition.contains('thunder')) {
      return Icons.thunderstorm;
    }

    if (condition.contains('rain') ||
        condition.contains('drizzle')) {
      return Icons.umbrella;
    }

    if (condition.contains('snow')) {
      return Icons.ac_unit;
    }

    if (condition.contains('cloud') ||
        condition.contains('overcast')) {
      return Icons.cloud;
    }

    if (condition.contains('clear')) {
      return Icons.wb_sunny;
    }

    return Icons.cloud_outlined;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading:
            false,
        toolbarHeight: 68,
        title: Row(
          children: [
            RichText(
              text: const TextSpan(
                style: TextStyle(
                  fontSize: 22,
                  fontWeight:
                      FontWeight.w900,
                  letterSpacing: -0.5,
                ),
                children: [
                  TextSpan(
                    text: 'Trek',
                    style: TextStyle(
                      color:
                          AppColors.textDark,
                    ),
                  ),
                  TextSpan(
                    text: 'Cure',
                    style: TextStyle(
                      color:
                          AppColors.primaryGreen,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, $_userName 👋',
                    overflow:
                        TextOverflow.ellipsis,
                    maxLines: 1,
                    style:
                        const TextStyle(
                      fontSize: 17,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 14,
                        color:
                            AppColors.textGrey,
                      ),

                      const SizedBox(width: 3),

                      Expanded(
                        child: Text(
                          _userLocationText,
                          overflow:
                              TextOverflow.ellipsis,
                          maxLines: 1,
                          style:
                              const TextStyle(
                            fontSize: 13,
                            color:
                                AppColors.textGrey,
                            fontWeight:
                                FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'TrekCure AI',
            icon: const Icon(
              Icons.auto_awesome,
              color:
                  AppColors.primaryGreen,
              size: 27,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const AiAgentScreen(),
                ),
              );
            },
          ),

          IconButton(
            icon: Stack(
              clipBehavior:
                  Clip.none,
              children: [
                const Icon(
                  Icons.notifications_none,
                  color:
                      AppColors.textDark,
                  size: 28,
                ),

                if (_unreadNotifications >
                    0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding:
                          const EdgeInsets.all(4),
                      decoration:
                          const BoxDecoration(
                        color:
                            AppColors.dangerRed,
                        shape:
                            BoxShape.circle,
                      ),
                      child: Text(
                        '$_unreadNotifications',
                        style:
                            const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const NotificationsScreen(),
                ),
              );

              if (mounted) {
                setState(() {
                  _unreadNotifications = 0;
                });
              }
            },
          ),

          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          padding:
              const EdgeInsets.fromLTRB(
            16,
            10,
            16,
            28,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              AppCard(
                color:
                    AppColors.lightGreenBg,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 4,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding:
                            const EdgeInsets.all(14),
                        decoration:
                            const BoxDecoration(
                          color:
                              AppColors.primaryGreen,
                          shape:
                              BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.shield,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),

                      const SizedBox(width: 16),

                      const Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'You are Safe',
                              style: TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                                fontSize: 19,
                              ),
                            ),

                            SizedBox(height: 4),

                            Text(
                              'Safety Status: Low Risk',
                              maxLines: 1,
                              overflow:
                                  TextOverflow.ellipsis,
                              style: TextStyle(
                                color:
                                    AppColors.textGrey,
                                fontSize: 15,
                                fontWeight:
                                    FontWeight.w500,
                              ),
                            ),

                            SizedBox(height: 2),

                            Text(
                              'Updated just now',
                              style: TextStyle(
                                color:
                                    AppColors.textGrey,
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: AppCard(
                        child: Padding(
                          padding:
                              const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Icon(
                                    _weatherIcon(),
                                    color:
                                        AppColors.infoBlue,
                                    size: 30,
                                  ),

                                  IconButton(
                                    padding:
                                        EdgeInsets.zero,
                                    constraints:
                                        const BoxConstraints(),
                                    iconSize: 22,
                                    tooltip: 'Refresh',
                                    onPressed:
                                        _weatherLoading
                                            ? null
                                            : _loadDashboardData,
                                    icon: const Icon(
                                      Icons.refresh,
                                      color:
                                          AppColors.textGrey,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 10),

                              Text(
                                _weatherLoading
                                    ? '--°C'
                                    : '${_temperature?.round() ?? 28}°C',
                                style:
                                    const TextStyle(
                                  fontSize: 28,
                                  fontWeight:
                                      FontWeight.bold,
                                  letterSpacing: -0.5,
                                ),
                              ),

                              Text(
                                _weatherCondition,
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis,
                                style:
                                    const TextStyle(
                                  color:
                                      AppColors.textGrey,
                                  fontSize: 15,
                                  fontWeight:
                                      FontWeight.w600,
                                ),
                              ),

                              const SizedBox(height: 12),

                              Row(
                                children: [
                                  const Icon(
                                    Icons.water_drop_outlined,
                                    size: 16,
                                    color:
                                        AppColors.infoBlue,
                                  ),

                                  const SizedBox(width: 4),

                                  Expanded(
                                    child: Text(
                                      _weatherLoading
                                          ? 'Humidity: --'
                                          : 'Humidity: ${_humidity?.round() ?? 75}%',
                                      maxLines: 1,
                                      overflow:
                                          TextOverflow.ellipsis,
                                      style:
                                          const TextStyle(
                                        fontSize: 14,
                                        fontWeight:
                                            FontWeight.w500,
                                        color:
                                            AppColors.textDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 4),

                              Row(
                                children: [
                                  const Icon(
                                    Icons.air,
                                    size: 16,
                                    color:
                                        AppColors.textGrey,
                                  ),

                                  const SizedBox(width: 4),

                                  Expanded(
                                    child: Text(
                                      _weatherLoading
                                          ? 'Wind: -- km/h'
                                          : 'Wind: ${_windSpeed?.round() ?? 12} km/h',
                                      maxLines: 1,
                                      overflow:
                                          TextOverflow.ellipsis,
                                      style:
                                          const TextStyle(
                                        fontSize: 14,
                                        fontWeight:
                                            FontWeight.w500,
                                        color:
                                            AppColors.textDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 14),

                    Expanded(
                      child: AppCard(
                        child: Padding(
                          padding:
                              const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Crowd Level',
                                style:
                                    TextStyle(
                                  color:
                                      AppColors.textGrey,
                                  fontSize: 15,
                                  fontWeight:
                                      FontWeight.w600,
                                ),
                              ),

                              const SizedBox(height: 10),

                              Row(
                                children: [
                                  Icon(
                                    Icons.groups,
                                    color: _crowdColor,
                                    size: 28,
                                  ),

                                  const SizedBox(width: 8),

                                  Expanded(
                                    child: Text(
                                      _crowdLevel,
                                      style:
                                          TextStyle(
                                        fontWeight:
                                            FontWeight.bold,
                                        color:
                                            _crowdColor,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 6),

                              Text(
                                _isCrowdLoading
                                    ? 'Calculating...'
                                    : '$_crowdPeopleCount people',
                                style:
                                    const TextStyle(
                                  fontSize: 16,
                                  fontWeight:
                                      FontWeight.bold,
                                  color:
                                      AppColors.textDark,
                                ),
                              ),

                              const SizedBox(height: 14),

                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const MapCrowdScreen(),
                                    ),
                                  );
                                },
                                child:
                                    const Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'View Details',
                                        style:
                                            TextStyle(
                                          color:
                                              AppColors.primaryGreen,
                                          fontSize: 14,
                                          fontWeight:
                                              FontWeight.bold,
                                        ),
                                      ),
                                    ),

                                    Icon(
                                      Icons.arrow_forward_ios,
                                      size: 13,
                                      color:
                                          AppColors.primaryGreen,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              AppCard(
                color:
                    AppColors.dangerBgLight,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 6,
                  ),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color:
                            AppColors.dangerRed,
                        size: 28,
                      ),

                      const SizedBox(width: 14),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Travel Alert',
                                    style:
                                        TextStyle(
                                      fontWeight:
                                          FontWeight.bold,
                                      fontSize: 17,
                                    ),
                                  ),
                                ),

                                Icon(
                                  Icons.chevron_right,
                                  size: 22,
                                ),
                              ],
                            ),

                            const SizedBox(height: 6),

                            Text(
                              'High crowd detected near\n$_nearbyAlertLocation. Avoid if possible.',
                              style:
                                  const TextStyle(
                                fontSize: 14.5,
                                height: 1.35,
                                color:
                                    AppColors.textGrey,
                                fontWeight:
                                    FontWeight.w500,
                              ),
                            ),

                            const SizedBox(height: 10),

                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const MapCrowdScreen(),
                                  ),
                                );
                              },
                              child:
                                  const Text(
                                'View on Map >',
                                style:
                                    TextStyle(
                                  color:
                                      AppColors.dangerRed,
                                  fontSize: 14,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // ==================================================
              // OFFLINE MESH STATUS
              // ==================================================

              AppCard(
                color:
                    const Color(0xFFF0FDF4),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 6,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding:
                            const EdgeInsets.all(14),
                        decoration:
                            BoxDecoration(
                          color: AppColors.primaryGreen
                              .withValues(
                            alpha: 0.15,
                          ),
                          shape:
                              BoxShape.circle,
                        ),
                        child: Icon(
                          _meshRelayActive
                              ? Icons.sensors
                              : Icons.sensors_off,
                          color:
                              _meshRelayActive
                                  ? AppColors.primaryGreen
                                  : AppColors.textGrey,
                          size: 28,
                        ),
                      ),

                      const SizedBox(width: 16),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _meshRelayActive
                                        ? 'Offline Mesh Active'
                                        : 'Offline Mesh Inactive',
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight.bold,
                                      fontSize: 16,
                                      color:
                                          AppColors.textDark,
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 6),

                                Text(
                                  '● $_nearbyMeshNodes ${_nearbyMeshNodes == 1 ? 'Node' : 'Nodes'}',
                                  style:
                                      TextStyle(
                                    fontWeight:
                                        FontWeight.bold,
                                    fontSize: 13,
                                    color:
                                        _meshRelayActive
                                            ? AppColors.primaryGreen
                                            : AppColors.textGrey,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 5),

                            Text(
                              !_meshRelayActive
                                  ? 'Offline mesh is currently inactive.'
                                  : _nearbyMeshNodes == 0
                                      ? 'Scanning for nearby relay peers...'
                                      : 'Connected to $_nearbyMeshNodes nearby mesh ${_nearbyMeshNodes == 1 ? 'node' : 'nodes'}. Ready to relay distress signals.',
                              style:
                                  const TextStyle(
                                fontSize: 13.5,
                                height: 1.35,
                                color:
                                    AppColors.textGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar:
          const AppBottomNav(
        currentIndex: 0,
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation
              .centerDocked,
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _meshNodeSubscription?.cancel();

    _sosSubscription?.cancel();

    super.dispose();
  }
}