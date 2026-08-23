import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';

class MapCrowdScreen extends StatefulWidget {
  const MapCrowdScreen({super.key});

  // Latest real location available from this screen.
  static Position? latestPosition;

  @override
  State<MapCrowdScreen> createState() =>
      _MapCrowdScreenState();
}

class _MapCrowdScreenState extends State<MapCrowdScreen> {
  // ============================================================
  // MAP
  // ============================================================

  final MapController _mapController = MapController();

  // ============================================================
  // SEARCH
  // ============================================================

  final TextEditingController _searchController =
      TextEditingController();

  Timer? _searchDebounce;

  List<_SearchPlace> _searchResults = [];

  bool _isSearching = false;

  // ============================================================
  // DESTINATION / ROUTE
  // ============================================================

  LatLng? _destination;

  List<LatLng> _routePoints = [];

  double? _routeDistanceKm;
  double? _routeDurationMinutes;

  bool _isLoadingRoute = false;

  // Prevent unnecessary route requests when GPS updates.
  LatLng? _lastRouteStart;

  // ============================================================
  // LOCATION
  // ============================================================

  LatLng? _userLocation;

  Position? _bestPosition;

  StreamSubscription<Position>? _locationSubscription;

  bool _isLoading = true;
  bool _locationError = false;
  bool _isGettingPreciseLocation = false;
  bool _precisePermission = false;

  String _locationStatus =
      'Getting precise location...';

  double? _accuracyMeters;
  double? _altitudeMeters;
  double? _altitudeAccuracyMeters;

  // ============================================================
  // CROWD
  // ============================================================

  List<WeightedLatLng> _crowdPoints = [];

  String _crowdLevel = 'Loading...';

  int _density = 0;

  // ============================================================
  // DISTANCE HELPER
  // ============================================================

  final Distance _distance = const Distance();

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // GET MOST ACCURATE LOCATION
  // ============================================================

  Future<void> _getLocation() async {
    if (_isGettingPreciseLocation) {
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _locationError = false;
        _isGettingPreciseLocation = true;
        _locationStatus =
            'Checking precise location...';
      });
    }

    try {
      // ========================================================
      // LOCATION SERVICE
      // ========================================================

      final bool serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        _showLocationError(
          'GPS/location services are disabled. Please turn them on.',
        );
        return;
      }

      // ========================================================
      // PERMISSION
      // ========================================================

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission =
            await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _showLocationError(
          'Location permission was denied.',
        );
        return;
      }

      if (permission ==
          LocationPermission.deniedForever) {
        _showLocationError(
          'Location permission is permanently denied. Please enable it in device settings.',
        );
        return;
      }

      // ========================================================
      // PRECISE / APPROXIMATE CHECK
      // ========================================================

      try {
        final LocationAccuracyStatus accuracyStatus =
            await Geolocator.getLocationAccuracy();

        _precisePermission =
            accuracyStatus ==
                LocationAccuracyStatus.precise;
      } catch (e) {
        debugPrint(
          'PRECISE LOCATION CHECK ERROR: $e',
        );

        _precisePermission = true;
      }

      if (!_precisePermission) {
        _showApproximateLocationDialog();
      }

      // ========================================================
      // MULTIPLE HIGH-ACCURACY READINGS
      // ========================================================

      Position? bestPosition;

      if (mounted) {
        setState(() {
          _locationStatus =
              'Finding your most accurate GPS position...';
        });
      }

      for (int i = 0; i < 6; i++) {
        try {
          final Position position =
              await Geolocator.getCurrentPosition(
            locationSettings:
                const LocationSettings(
              accuracy:
                  LocationAccuracy.bestForNavigation,
              distanceFilter: 0,
              timeLimit:
                  Duration(seconds: 15),
            ),
          );

          debugPrint(
            'GPS READING ${i + 1}: '
            '${position.latitude}, '
            '${position.longitude} '
            'accuracy=${position.accuracy}m',
          );

          if (bestPosition == null ||
              position.accuracy <
                  bestPosition.accuracy) {
            bestPosition = position;
          }

          if (mounted) {
            setState(() {
              _locationStatus =
                  'Improving GPS accuracy... '
                  '±${position.accuracy.toStringAsFixed(1)} m';
            });
          }

          if (position.accuracy <= 5) {
            break;
          }
        } on TimeoutException catch (e) {
          debugPrint(
            'GPS READING TIMEOUT ${i + 1}: $e',
          );
        } catch (e) {
          debugPrint(
            'GPS READING ERROR ${i + 1}: $e',
          );
        }
      }

      // ========================================================
      // LAST KNOWN LOCATION FALLBACK
      // ========================================================

      if (bestPosition == null) {
        try {
          final Position? lastKnownPosition =
              await Geolocator.getLastKnownPosition();

          if (lastKnownPosition != null) {
            bestPosition = lastKnownPosition;
          }
        } catch (e) {
          debugPrint(
            'LAST KNOWN LOCATION ERROR: $e',
          );
        }
      }

      // ========================================================
      // NO LOCATION
      // ========================================================

      if (bestPosition == null) {
        _showLocationError(
          'Unable to get your location. Move outdoors or to an area with better GPS reception and try again.',
        );
        return;
      }

      // ========================================================
      // APPLY BEST LOCATION
      // ========================================================

      await _updateLocation(
        bestPosition,
        moveMap: true,
      );

      // ========================================================
      // START CONTINUOUS TRACKING
      // ========================================================

      await _startLocationStream();

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isGettingPreciseLocation = false;
      });
    } on TimeoutException catch (e) {
      debugPrint(
        'GPS MAIN TIMEOUT: $e',
      );

      _showLocationError(
        'GPS took too long to get an accurate location.',
      );
    } catch (e) {
      debugPrint(
        'GPS MAIN ERROR: $e',
      );

      _showLocationError(
        'Unable to get your current location.',
      );
    }
  }

  // ============================================================
  // CONTINUOUS LOCATION TRACKING
  // ============================================================

  Future<void> _startLocationStream() async {
    await _locationSubscription?.cancel();

    _locationSubscription =
        Geolocator.getPositionStream(
      locationSettings:
          const LocationSettings(
        accuracy:
            LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).listen(
      (Position position) async {
        await _updateLocation(
          position,
          moveMap: false,
        );

        if (_destination != null &&
            _userLocation != null &&
            _shouldRefreshRoute(
              _userLocation!,
            )) {
          await _getRouteToDestination(
            _destination!,
            showLoading: false,
          );
        }
      },
      onError: (Object error) {
        debugPrint(
          'LOCATION STREAM ERROR: $error',
        );
      },
    );
  }

  // ============================================================
  // SHOULD REFRESH ROUTE
  // ============================================================

  bool _shouldRefreshRoute(
    LatLng currentLocation,
  ) {
    if (_lastRouteStart == null) {
      return true;
    }

    final double meters =
        _distance(
      _lastRouteStart!,
      currentLocation,
    );

    return meters >= 50;
  }

  // ============================================================
  // APPLY LOCATION
  // ============================================================

  Future<void> _updateLocation(
    Position position, {
    bool moveMap = false,
  }) async {
    if (!mounted) return;

    if (_bestPosition != null &&
        position.accuracy >
            _bestPosition!.accuracy + 20 &&
        position.accuracy > 30) {
      return;
    }

    _bestPosition = position;

    final LatLng currentLocation =
        LatLng(
      position.latitude,
      position.longitude,
    );

    // ========================================================
    // ACCURACY
    // ========================================================

    final double accuracy =
        position.accuracy;

    String accuracyText;

    if (accuracy <= 5) {
      accuracyText =
          'Very accurate • ±${accuracy.toStringAsFixed(1)} m';
    } else if (accuracy <= 10) {
      accuracyText =
          'High accuracy • ±${accuracy.toStringAsFixed(1)} m';
    } else if (accuracy <= 25) {
      accuracyText =
          'Good accuracy • ±${accuracy.toStringAsFixed(1)} m';
    } else if (accuracy <= 50) {
      accuracyText =
          'Moderate accuracy • ±${accuracy.toStringAsFixed(1)} m';
    } else {
      accuracyText =
          'Low accuracy • ±${accuracy.toStringAsFixed(1)} m';
    }

    // ========================================================
    // ALTITUDE
    // ========================================================

    final double? altitude =
        position.altitude;

    final double? altitudeAccuracy =
        position.altitudeAccuracy;

    // ========================================================
    // SAVE LATEST REAL LOCATION
    // ========================================================

    MapCrowdScreen.latestPosition =
        position;

    if (!mounted) return;

    setState(() {
      _userLocation =
          currentLocation;

      _bestPosition =
          position;

      _accuracyMeters =
          accuracy;

      _altitudeMeters =
          altitude;

      _altitudeAccuracyMeters =
          altitudeAccuracy;

      _locationStatus =
          accuracyText;

      _locationError =
          false;

      _isLoading =
          false;
    });

    _generateCrowdData(
      currentLocation,
    );

    if (moveMap) {
      _mapController.move(
        currentLocation,
        17.0,
      );
    }
  }

  // ============================================================
  // SEARCH INPUT
  // ============================================================

  void _onSearchChanged(
    String value,
  ) {
    _searchDebounce?.cancel();

    if (value.trim().length < 2) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
      return;
    }

    _searchDebounce =
        Timer(
      const Duration(milliseconds: 650),
      () {
        _searchPlaces(
          value.trim(),
        );
      },
    );
  }

  // ============================================================
  // SEARCH PLACES
  // ============================================================

  Future<void> _searchPlaces(
    String query,
  ) async {
    if (query.isEmpty) {
      return;
    }

    if (!mounted) return;

    setState(() {
      _isSearching = true;
    });

    try {
      final Uri url = Uri.https(
        'nominatim.openstreetmap.org',
        '/search',
        {
          'q': query,
          'format': 'jsonv2',
          'limit': '5',
          'addressdetails': '1',
        },
      );

      final http.Response response =
          await http.get(
        url,
        headers: const {
          'User-Agent':
              'TrekCure/1.0 (tourist-safety-app)',
          'Accept':
              'application/json',
        },
      ).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Search service returned ${response.statusCode}',
        );
      }

      final dynamic decoded =
          jsonDecode(response.body);

      if (decoded is! List) {
        throw Exception(
          'Invalid search response',
        );
      }

      final List<_SearchPlace> results =
          decoded
              .whereType<
                  Map<String, dynamic>>()
              .map(
                (
                  Map<String, dynamic> item,
                ) {
                  final double? latitude =
                      double.tryParse(
                    '${item['lat'] ?? ''}',
                  );

                  final double? longitude =
                      double.tryParse(
                    '${item['lon'] ?? ''}',
                  );

                  if (latitude == null ||
                      longitude == null) {
                    return null;
                  }

                  return _SearchPlace(
                    name:
                        '${item['display_name'] ?? 'Unknown location'}',
                    latitude:
                        latitude,
                    longitude:
                        longitude,
                  );
                },
              )
              .whereType<
                  _SearchPlace>()
              .toList();

      if (!mounted) return;

      setState(() {
        _searchResults =
            results;
        _isSearching =
            false;
      });
    } catch (e) {
      debugPrint(
        'LOCATION SEARCH ERROR: $e',
      );

      if (!mounted) return;

      setState(() {
        _searchResults = [];
        _isSearching =
            false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text(
            'Unable to search for that location.',
          ),
        ),
      );
    }
  }

  // ============================================================
  // SELECT SEARCH RESULT
  // ============================================================

  Future<void> _selectSearchPlace(
    _SearchPlace place,
  ) async {
    FocusScope.of(context).unfocus();

    _searchController.text =
        place.shortName;

    if (!mounted) return;

    setState(() {
      _searchResults = [];
    });

    final LatLng destination =
        LatLng(
      place.latitude,
      place.longitude,
    );

    await _getRouteToDestination(
      destination,
      showLoading: true,
    );
  }

  // ============================================================
  // GET SHORTEST ROUTE
  // ============================================================

  Future<void> _getRouteToDestination(
    LatLng destination, {
    bool showLoading = true,
  }) async {
    final LatLng? start =
        _userLocation;

    if (start == null) {
      _showMessage(
        'Your current location is not available yet.',
      );
      return;
    }

    if (showLoading && mounted) {
      setState(() {
        _isLoadingRoute = true;
        _routePoints = [];
        _routeDistanceKm = null;
        _routeDurationMinutes = null;
      });
    }

    try {
      final String coordinates =
          '${start.longitude},${start.latitude};'
          '${destination.longitude},${destination.latitude}';

      final Uri url =
          Uri.parse(
        'https://router.project-osrm.org/'
        'route/v1/driving/'
        '$coordinates'
        '?overview=full'
        '&geometries=geojson'
        '&steps=true'
        '&alternatives=true',
      );

      debugPrint(
        'REQUESTING ROUTES FROM '
        '$start TO $destination',
      );

      final http.Response response =
          await http.get(
        url,
        headers: const {
          'User-Agent':
              'TrekCure/1.0 (tourist-safety-app)',
          'Accept':
              'application/json',
        },
      ).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Route service returned ${response.statusCode}',
        );
      }

      final dynamic decoded =
          jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw Exception(
          'Invalid route response',
        );
      }

      final String code =
          '${decoded['code'] ?? ''}';

      if (code != 'Ok') {
        throw Exception(
          'No route found',
        );
      }

      final List<dynamic> routes =
          decoded['routes']
                  as List<dynamic>? ??
              [];

      if (routes.isEmpty) {
        throw Exception(
          'No route found',
        );
      }

      Map<String, dynamic>? shortestRoute;

      double shortestDistance =
          double.infinity;

      for (final dynamic routeItem
          in routes) {
        if (routeItem is! Map) {
          continue;
        }

        final Map<String, dynamic> route =
            Map<String, dynamic>.from(
          routeItem,
        );

        final double distanceMeters =
            (route['distance'] as num?)
                    ?.toDouble() ??
                double.infinity;

        if (distanceMeters <
            shortestDistance) {
          shortestDistance =
              distanceMeters;

          shortestRoute =
              route;
        }
      }

      if (shortestRoute == null) {
        throw Exception(
          'Could not determine the shortest available route.',
        );
      }

      final double distanceMeters =
          (shortestRoute['distance'] as num?)
                  ?.toDouble() ??
              0;

      final double durationSeconds =
          (shortestRoute['duration'] as num?)
                  ?.toDouble() ??
              0;

      final Map<String, dynamic> geometry =
          Map<String, dynamic>.from(
        shortestRoute['geometry']
            as Map,
      );

      final List<dynamic> coordinatesList =
          geometry['coordinates']
                  as List<dynamic>? ??
              [];

      final List<LatLng>
          routePoints = [];

      for (final dynamic item
          in coordinatesList) {
        if (item is List &&
            item.length >= 2) {
          final double? longitude =
              (item[0] as num?)
                  ?.toDouble();

          final double? latitude =
              (item[1] as num?)
                  ?.toDouble();

          if (latitude != null &&
              longitude != null) {
            routePoints.add(
              LatLng(
                latitude,
                longitude,
              ),
            );
          }
        }
      }

      if (routePoints.isEmpty) {
        throw Exception(
          'Route geometry is empty',
        );
      }

      if (!mounted) return;

      setState(() {
        _destination =
            destination;

        _routePoints =
            routePoints;

        _routeDistanceKm =
            distanceMeters / 1000;

        _routeDurationMinutes =
            durationSeconds / 60;

        _isLoadingRoute =
            false;

        _lastRouteStart =
            start;
      });

      debugPrint(
        'SHORTEST ROUTE: '
        '${(distanceMeters / 1000).toStringAsFixed(2)} km '
        '• '
        '${(durationSeconds / 60).toStringAsFixed(0)} min',
      );

      WidgetsBinding.instance
          .addPostFrameCallback(
        (_) {
          if (!mounted ||
              _routePoints.isEmpty) {
            return;
          }

          try {
            final LatLngBounds bounds =
                LatLngBounds.fromPoints(
              _routePoints,
            );

            _mapController.fitCamera(
              CameraFit.bounds(
                bounds: bounds,
                padding:
                    const EdgeInsets.all(
                  35,
                ),
              ),
            );
          } catch (e) {
            debugPrint(
              'FIT ROUTE CAMERA ERROR: $e',
            );

            _mapController.move(
              destination,
              14.0,
            );
          }
        },
      );
    } catch (e) {
      debugPrint(
        'ROUTE ERROR: $e',
      );

      if (!mounted) return;

      setState(() {
        _isLoadingRoute =
            false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text(
            'Could not find a route to this location.',
          ),
        ),
      );
    }
  }

  // ============================================================
  // CLEAR ROUTE
  // ============================================================

  void _clearRoute() {
    FocusScope.of(context).unfocus();

    _searchController.clear();

    if (!mounted) return;

    setState(() {
      _destination = null;
      _routePoints = [];
      _routeDistanceKm = null;
      _routeDurationMinutes = null;
      _searchResults = [];
      _lastRouteStart = null;
    });

    if (_userLocation != null) {
      _mapController.move(
        _userLocation!,
        17.0,
      );
    }
  }

  // ============================================================
  // APPROXIMATE LOCATION WARNING
  // ============================================================

  void _showApproximateLocationDialog() {
    if (!mounted) return;

    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        if (!mounted) return;

        showDialog(
          context: context,
          builder:
              (
            BuildContext dialogContext,
          ) {
            return AlertDialog(
              title:
                  const Text(
                'Precise location is off',
              ),
              content:
                  const Text(
                'TrekCure has approximate location permission. For the best possible GPS accuracy, enable Precise Location in your device settings.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                    );
                  },
                  child:
                      const Text(
                    'Later',
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                    );

                    Geolocator
                        .openAppSettings();
                  },
                  child:
                      const Text(
                    'Open Settings',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // CROWD DATA
  // ============================================================

  void _generateCrowdData(
    LatLng center,
  ) {
    final Random random =
        Random();

    final List<WeightedLatLng>
        points = [];

    double totalDensity =
        0;

    for (int i = 0;
        i < 100;
        i++) {
      final double latitudeOffset =
          (random.nextDouble() -
                  0.5) *
              0.05;

      final double longitudeOffset =
          (random.nextDouble() -
                  0.5) *
              0.05;

      final double density =
          0.1 +
              random.nextDouble() *
                  0.9;

      totalDensity +=
          density;

      points.add(
        WeightedLatLng(
          LatLng(
            center.latitude +
                latitudeOffset,
            center.longitude +
                longitudeOffset,
          ),
          density,
        ),
      );
    }

    final double averageDensity =
        totalDensity /
            points.length;

    final int percentage =
        (averageDensity * 100)
            .round();

    String level;

    if (percentage <= 30) {
      level =
          'Low';
    } else if (percentage <= 70) {
      level =
          'Moderate';
    } else {
      level =
          'High';
    }

    if (!mounted) return;

    setState(() {
      _crowdPoints =
          points;

      _density =
          percentage;

      _crowdLevel =
          level;
    });
  }

  // ============================================================
  // REFRESH LOCATION
  // ============================================================

  Future<void> _refreshLocation() async {
    await _getLocation();

    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content:
            Text(
          'Location updated',
        ),
        duration:
            Duration(seconds: 1),
      ),
    );
  }

  // ============================================================
  // MOVE TO USER
  // ============================================================

  void _goToCurrentLocation() {
    if (_userLocation == null) {
      _getLocation();
      return;
    }

    _mapController.move(
      _userLocation!,
      18.0,
    );
  }

  // ============================================================
  // LOCATION DETAILS
  // ============================================================

  void _showLocationDetails() {
    final Position? position =
        _bestPosition;

    if (position == null) {
      _showMessage(
        'Location is not available yet.',
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder:
          (
        BuildContext sheetContext,
      ) {
        return SafeArea(
          child:
              Padding(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              4,
              20,
              24,
            ),
            child:
                Column(
              mainAxisSize:
                  MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Precise GPS Location',
                  style:
                      TextStyle(
                    fontSize:
                        20,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height:
                      18,
                ),

                _detailRow(
                  Icons.location_on,
                  'Latitude',
                  position.latitude
                      .toStringAsFixed(
                    7,
                  ),
                ),

                _detailRow(
                  Icons.location_on,
                  'Longitude',
                  position.longitude
                      .toStringAsFixed(
                    7,
                  ),
                ),

                _detailRow(
                  Icons.gps_fixed,
                  'Horizontal accuracy',
                  '±${position.accuracy.toStringAsFixed(1)} m',
                ),

                _detailRow(
                  Icons.height,
                  'Elevation',
                  '${_altitudeMeters?.toStringAsFixed(1) ?? '--'} m',
                ),

                if (_altitudeAccuracyMeters !=
                    null)
                  _detailRow(
                    Icons.vertical_align_center,
                    'Vertical accuracy',
                    '±${_altitudeAccuracyMeters!.toStringAsFixed(1)} m',
                  ),

                const SizedBox(
                  height:
                      12,
                ),

                Container(
                  width:
                      double.infinity,
                  padding:
                      const EdgeInsets.all(
                    14,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        AppColors.lightGreenBg,
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                  child:
                      const Text(
                    'The location shown is the actual GPS position reported by the device. Accuracy depends on GPS signal quality, device hardware and the surrounding environment.',
                    style:
                        TextStyle(
                      fontSize:
                          12,
                      color:
                          AppColors.textGrey,
                      height:
                          1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // DETAIL ROW
  // ============================================================

  Widget _detailRow(
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom:
            13,
      ),
      child:
          Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size:
                20,
            color:
                AppColors.primaryGreen,
          ),
          const SizedBox(
            width:
                10,
          ),
          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style:
                      const TextStyle(
                    fontSize:
                        11,
                    color:
                        AppColors.textGrey,
                  ),
                ),
                const SizedBox(
                  height:
                      2,
                ),
                Text(
                  value,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _showLocationError(
    String message,
  ) {
    if (!mounted) return;

    setState(() {
      _isLoading =
          false;

      _isGettingPreciseLocation =
          false;

      _locationError =
          true;

      _locationStatus =
          'Location unavailable';
    });

    _showMessage(
      message,
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content:
            Text(message),
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
    return Scaffold(
      appBar:
          AppBar(
        toolbarHeight:
            48,
        title:
            const Text(
          'Crowd Map',
          style:
              TextStyle(
            fontWeight:
                FontWeight.bold,
            fontSize:
                16,
          ),
        ),
        actions: [
          IconButton(
            onPressed:
                _refreshLocation,
            tooltip:
                'Update location',
            icon:
                const Icon(
              Icons.my_location,
              size:
                  20,
            ),
          ),
          IconButton(
            onPressed:
                _showLocationDetails,
            tooltip:
                'Location details',
            icon:
                const Icon(
              Icons.info_outline,
              size:
                  20,
            ),
          ),
          IconButton(
            onPressed:
                () {
              if (_userLocation ==
                  null) {
                _getLocation();
              } else {
                _generateCrowdData(
                  _userLocation!,
                );
              }
            },
            tooltip:
                'Refresh crowd',
            icon:
                const Icon(
              Icons.refresh,
              size:
                  20,
            ),
          ),
        ],
      ),

      body:
          Column(
        children: [
          _buildSearchSection(),

          _buildCompactLocationCard(),

          Expanded(
            child:
                Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                10,
                0,
                10,
                4,
              ),
              child:
                  ClipRRect(
                borderRadius:
                    BorderRadius.circular(
                  16,
                ),
                child:
                    _buildMap(),
              ),
            ),
          ),

          _buildCompactLegend(),

          _buildCompactCrowdCard(),
        ],
      ),

      floatingActionButton:
          FloatingActionButton(
        mini:
            true,
        onPressed:
            _goToCurrentLocation,
        tooltip:
            'My Location',
        child:
            const Icon(
          Icons.my_location,
          size:
              20,
        ),
      ),

      bottomNavigationBar:
          const AppBottomNav(
        currentIndex:
            1,
      ),
    );
  }

  // ============================================================
  // SEARCH SECTION
  // ============================================================

  Widget _buildSearchSection() {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        12,
        5,
        12,
        4,
      ),
      child:
          Column(
        children: [
          SizedBox(
            height:
                44,
            child:
                Material(
              elevation:
                  2,
              borderRadius:
                  BorderRadius.circular(
                13,
              ),
              child:
                  TextField(
                controller:
                    _searchController,
                onChanged:
                    _onSearchChanged,
                textInputAction:
                    TextInputAction.search,
                style:
                    const TextStyle(
                  fontSize:
                      12,
                ),
                decoration:
                    InputDecoration(
                  hintText:
                      'Search a location...',
                  hintStyle:
                      const TextStyle(
                    fontSize:
                        12,
                  ),
                  prefixIcon:
                      const Icon(
                    Icons.search,
                    size:
                        19,
                  ),
                  suffixIcon:
                      _searchController
                              .text
                              .isEmpty
                          ? null
                          : IconButton(
                              onPressed:
                                  _clearRoute,
                              icon:
                                  const Icon(
                                Icons.clear,
                                size:
                                    18,
                              ),
                            ),
                  filled:
                      true,
                  fillColor:
                      Colors.white,
                  border:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                      13,
                    ),
                    borderSide:
                        BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(
                    vertical:
                        8,
                    horizontal:
                        12,
                  ),
                ),
              ),
            ),
          ),

          if (_isSearching)
            const Padding(
              padding:
                  EdgeInsets.only(
                top:
                    5,
              ),
              child:
                  Row(
                children: [
                  SizedBox(
                    width:
                        16,
                    height:
                        16,
                    child:
                        CircularProgressIndicator(
                      strokeWidth:
                          2,
                    ),
                  ),
                  SizedBox(
                    width:
                        8,
                  ),
                  Text(
                    'Searching...',
                    style:
                        TextStyle(
                      fontSize:
                          11,
                    ),
                  ),
                ],
              ),
            ),

          if (!_isSearching &&
              _searchResults.isNotEmpty)
            Container(
              width:
                  double.infinity,
              constraints:
                  const BoxConstraints(
                maxHeight:
                    180,
              ),
              margin:
                  const EdgeInsets.only(
                top:
                    4,
              ),
              decoration:
                  BoxDecoration(
                color:
                    Colors.white,
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
                boxShadow:
                    const [
                  BoxShadow(
                    blurRadius:
                        8,
                    offset:
                        Offset(
                      0,
                      2,
                    ),
                    color:
                        Colors.black12,
                  ),
                ],
              ),
              child:
                  ListView.separated(
                shrinkWrap:
                    true,
                padding:
                    EdgeInsets.zero,
                itemCount:
                    _searchResults.length,
                separatorBuilder:
                    (_, __) =>
                        const Divider(
                  height:
                      1,
                ),
                itemBuilder:
                    (
                  context,
                  index,
                ) {
                  final _SearchPlace place =
                      _searchResults[
                          index];

                  return ListTile(
                    dense:
                        true,
                    visualDensity:
                        const VisualDensity(
                      vertical:
                          -2,
                    ),
                    leading:
                        const Icon(
                      Icons.location_on,
                      size:
                          20,
                      color:
                          AppColors
                              .primaryGreen,
                    ),
                    title:
                        Text(
                      place.shortName,
                      maxLines:
                          1,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        fontSize:
                            12,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                    subtitle:
                        Text(
                      place.name,
                      maxLines:
                          1,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        fontSize:
                            9,
                      ),
                    ),
                    onTap:
                        () =>
                            _selectSearchPlace(
                      place,
                    ),
                  );
                },
              ),
            ),

          if (_routeDistanceKm != null)
            Padding(
              padding:
                  const EdgeInsets.only(
                top:
                    4,
              ),
              child:
                  _buildRouteInfo(),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // ROUTE INFO
  // ============================================================

  Widget _buildRouteInfo() {
    return Container(
      height:
          38,
      width:
          double.infinity,
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            10,
      ),
      decoration:
          BoxDecoration(
        color:
            AppColors.lightGreenBg,
        borderRadius:
            BorderRadius.circular(
          10,
        ),
      ),
      child:
          Row(
        children: [
          const Icon(
            Icons.route,
            color:
                AppColors.primaryGreen,
            size:
                17,
          ),
          const SizedBox(
            width:
                6,
          ),
          Expanded(
            child:
                Text(
              'Shortest route • '
              '${_formatDistance(_routeDistanceKm ?? 0)}'
              ' • '
              '${_formatRouteDuration(
                _routeDurationMinutes ?? 0,
              )}',
              style:
                  const TextStyle(
                fontSize:
                    10,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),
          if (_isLoadingRoute)
            const SizedBox(
              width:
                  15,
              height:
                  15,
              child:
                  CircularProgressIndicator(
                strokeWidth:
                    2,
              ),
            ),
          IconButton(
            padding:
                EdgeInsets.zero,
            constraints:
                const BoxConstraints(
              minWidth:
                  28,
              minHeight:
                  28,
            ),
            onPressed:
                _clearRoute,
            tooltip:
                'Clear route',
            icon:
                const Icon(
              Icons.close,
              size:
                  16,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FORMAT DISTANCE
  // ============================================================

  String _formatDistance(
    double km,
  ) {
    if (km < 1) {
      return '${(km * 1000).round()} m';
    }

    return '${km.toStringAsFixed(1)} km';
  }

  // ============================================================
  // FORMAT ROUTE TIME
  // ============================================================

  String _formatRouteDuration(
    double minutes,
  ) {
    if (minutes < 1) {
      return '<1 min';
    }

    final int roundedMinutes =
        minutes.round();

    if (roundedMinutes < 60) {
      return '$roundedMinutes min';
    }

    final int hours =
        roundedMinutes ~/ 60;

    final int remainingMinutes =
        roundedMinutes % 60;

    if (remainingMinutes == 0) {
      return '${hours}h';
    }

    return '${hours}h ${remainingMinutes}m';
  }

  // ============================================================
  // COMPACT LOCATION CARD
  // ============================================================

  Widget _buildCompactLocationCard() {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        12,
        1,
        12,
        4,
      ),
      child:
          Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal:
              10,
          vertical:
              7,
        ),
        decoration:
            BoxDecoration(
          color:
              Colors.white,
          borderRadius:
              BorderRadius.circular(
            12,
          ),
          border:
              Border.all(
            color:
                Colors.black12,
          ),
        ),
        child:
            Row(
          children: [
            Container(
              width:
                  34,
              height:
                  34,
              decoration:
                  BoxDecoration(
                color:
                    AppColors.lightGreenBg,
                shape:
                    BoxShape.circle,
              ),
              child:
                  const Icon(
                Icons.gps_fixed,
                color:
                    AppColors.primaryGreen,
                size:
                    18,
              ),
            ),
            const SizedBox(
              width:
                  8,
            ),
            Expanded(
              child:
                  Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Current Location',
                        style:
                            TextStyle(
                          fontSize:
                              11,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      const SizedBox(
                        width:
                            5,
                      ),
                      if (_precisePermission)
                        const Icon(
                          Icons.check_circle,
                          color:
                              AppColors
                                  .primaryGreen,
                          size:
                              13,
                        ),
                    ],
                  ),
                  const SizedBox(
                    height:
                        2,
                  ),
                  Text(
                    _bestPosition == null
                        ? 'Waiting for GPS...'
                        : '${_bestPosition!.latitude.toStringAsFixed(5)}, '
                          '${_bestPosition!.longitude.toStringAsFixed(5)}',
                    maxLines:
                        1,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      fontSize:
                          9,
                      color:
                          AppColors
                              .textGrey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(
              width:
                  8,
            ),
            Column(
              crossAxisAlignment:
                  CrossAxisAlignment.end,
              children: [
                const Text(
                  'Accuracy',
                  style:
                      TextStyle(
                    fontSize:
                        8,
                    color:
                        AppColors
                            .textGrey,
                  ),
                ),
                Text(
                  _accuracyMeters ==
                          null
                      ? '--'
                      : '±${_accuracyMeters!.toStringAsFixed(1)} m',
                  style:
                      const TextStyle(
                    fontSize:
                        9,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MAP
  // ============================================================

  Widget _buildMap() {
    const LatLng defaultLocation =
        LatLng(
      19.0760,
      72.8777,
    );

    return FlutterMap(
      mapController:
          _mapController,
      options:
          MapOptions(
        initialCenter:
            _userLocation ??
                defaultLocation,
        initialZoom:
            17.0,
        minZoom:
            5.0,
        maxZoom:
            20.0,
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName:
              'com.trekcure.app',
        ),

        // ======================================================
        // CROWD HEATMAP
        // ======================================================

        if (_crowdPoints.isNotEmpty)
          HeatMapLayer(
            heatMapDataSource:
                InMemoryHeatMapDataSource(
              data:
                  _crowdPoints,
            ),
            heatMapOptions:
                HeatMapOptions(
              radius:
                  35,
              blurFactor:
                  0.8,
              minOpacity:
                  0.25,
              gradient: {
                0.0:
                    Colors.green,
                0.35:
                    Colors.yellow,
                0.60:
                    Colors.orange,
                1.0:
                    Colors.red,
              },
            ),
          ),

        // ======================================================
        // SHORTEST ROUTE
        // ======================================================

        if (_routePoints.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points:
                    _routePoints,
                strokeWidth:
                    5,
                color:
                    AppColors.primaryGreen,
              ),
            ],
          ),

        // ======================================================
        // CURRENT LOCATION
        // ======================================================

        if (_userLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point:
                    _userLocation!,
                width:
                    62,
                height:
                    62,
                child:
                    Stack(
                  alignment:
                      Alignment.center,
                  children: [
                    Container(
                      width:
                          44,
                      height:
                          44,
                      decoration:
                          BoxDecoration(
                        color:
                            Colors.blue.withValues(
                          alpha:
                              0.18,
                        ),
                        shape:
                            BoxShape.circle,
                      ),
                    ),
                    const Icon(
                      Icons.location_on,
                      color:
                          Colors.blue,
                      size:
                          34,
                    ),
                  ],
                ),
              ),
            ],
          ),

        // ======================================================
        // DESTINATION
        // ======================================================

        if (_destination != null)
          MarkerLayer(
            markers: [
              Marker(
                point:
                    _destination!,
                width:
                    55,
                height:
                    55,
                child:
                    const Icon(
                  Icons.location_pin,
                  color:
                      Colors.red,
                  size:
                      42,
                ),
              ),
            ],
          ),

        // ======================================================
        // ROUTE LOADING
        // ======================================================

        if (_isLoadingRoute)
          const Center(
            child:
                Card(
              child:
                  Padding(
                padding:
                    EdgeInsets.all(
                  14,
                ),
                child:
                    Row(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    SizedBox(
                      width:
                          20,
                      height:
                          20,
                      child:
                          CircularProgressIndicator(
                        strokeWidth:
                            2,
                      ),
                    ),
                    SizedBox(
                      width:
                          10,
                    ),
                    Text(
                      'Finding shortest route...',
                      style:
                          TextStyle(
                        fontSize:
                            12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // ======================================================
        // LOCATION LOADING
        // ======================================================

        if (_isLoading)
          const Center(
            child:
                CircularProgressIndicator(),
          ),

        // ======================================================
        // LOCATION ERROR
        // ======================================================

        if (_locationError)
          Center(
            child:
                Container(
              margin:
                  const EdgeInsets.all(
                30,
              ),
              padding:
                  const EdgeInsets.all(
                20,
              ),
              decoration:
                  BoxDecoration(
                color:
                    Colors.white,
                borderRadius:
                    BorderRadius.circular(
                  16,
                ),
                boxShadow:
                    const [
                  BoxShadow(
                    blurRadius:
                        10,
                    color:
                        Colors.black26,
                  ),
                ],
              ),
              child:
                  Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.location_off,
                    size:
                        40,
                    color:
                        Colors.red,
                  ),
                  const SizedBox(
                    height:
                        10,
                  ),
                  const Text(
                    'Location unavailable',
                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight.bold,
                      fontSize:
                          16,
                    ),
                  ),
                  const SizedBox(
                    height:
                        10,
                  ),
                  ElevatedButton(
                    onPressed:
                        _getLocation,
                    child:
                        const Text(
                      'Try Again',
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // COMPACT LEGEND
  // ============================================================

  Widget _buildCompactLegend() {
    return SizedBox(
      height:
          24,
      child:
          Row(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          _buildLegendItem(
            Colors.green,
            'Low',
          ),
          const SizedBox(
            width:
                18,
          ),
          _buildLegendItem(
            Colors.orange,
            'Moderate',
          ),
          const SizedBox(
            width:
                18,
          ),
          _buildLegendItem(
            Colors.red,
            'High',
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(
    Color color,
    String label,
  ) {
    return Row(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        Container(
          width:
              9,
          height:
              9,
          decoration:
              BoxDecoration(
            color:
                color,
            shape:
                BoxShape.circle,
          ),
        ),
        const SizedBox(
          width:
              4,
        ),
        Text(
          label,
          style:
              const TextStyle(
            fontSize:
                9,
            color:
                AppColors.textGrey,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // COMPACT CROWD CARD
  // ============================================================

  Widget _buildCompactCrowdCard() {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        12,
        2,
        12,
        6,
      ),
      child:
          Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal:
              12,
          vertical:
              7,
        ),
        decoration:
            BoxDecoration(
          color:
              Colors.white,
          borderRadius:
              BorderRadius.circular(
            12,
          ),
          border:
              Border.all(
            color:
                Colors.black12,
          ),
        ),
        child:
            Row(
          children: [
            const Icon(
              Icons.groups,
              size:
                  20,
              color:
                  AppColors.primaryGreen,
            ),
            const SizedBox(
              width:
                  8,
            ),
            const Expanded(
              child:
                  Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'Crowd Overview',
                    style:
                        TextStyle(
                      fontSize:
                          10,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  SizedBox(
                    height:
                        1,
                  ),
                  Text(
                    'Around your current location',
                    style:
                        TextStyle(
                      fontSize:
                          8,
                      color:
                          AppColors.textGrey,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Text(
                  _crowdLevel,
                  style:
                      TextStyle(
                    fontSize:
                        10,
                    fontWeight:
                        FontWeight.bold,
                    color:
                        _getCrowdColor(),
                  ),
                ),
                const Text(
                  'Crowd',
                  style:
                      TextStyle(
                    fontSize:
                        8,
                    color:
                        AppColors.textGrey,
                  ),
                ),
              ],
            ),
            const SizedBox(
              width:
                  18,
            ),
            Column(
              children: [
                Text(
                  '$_density%',
                  style:
                      TextStyle(
                    fontSize:
                        10,
                    fontWeight:
                        FontWeight.bold,
                    color:
                        _getCrowdColor(),
                  ),
                ),
                const Text(
                  'Density',
                  style:
                      TextStyle(
                    fontSize:
                        8,
                    color:
                        AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CROWD COLOR
  // ============================================================

  Color _getCrowdColor() {
    if (_density <= 30) {
      return Colors.green;
    }

    if (_density <= 70) {
      return Colors.orange;
    }

    return Colors.red;
  }
}

// ==================================================================
// SEARCH PLACE MODEL
// ==================================================================

class _SearchPlace {
  final String name;
  final double latitude;
  final double longitude;

  const _SearchPlace({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  String get shortName {
    final List<String> parts =
        name.split(',');

    if (parts.isEmpty) {
      return name;
    }

    return parts.first.trim();
  }
}