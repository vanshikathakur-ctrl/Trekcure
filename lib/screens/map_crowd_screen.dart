import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';

class MapCrowdScreen extends StatefulWidget {
  const MapCrowdScreen({super.key});

  // Latest real location available from this screen.
  // Other parts of the app can access these values later.
  static Position? latestPosition;
  static int? latestFloor;

  @override
  State<MapCrowdScreen> createState() => _MapCrowdScreenState();
}

class _MapCrowdScreenState extends State<MapCrowdScreen> {
  // ============================================================
  // MAP
  // ============================================================

  final MapController _mapController = MapController();

  // ============================================================
  // LOCATION
  // ============================================================

  LatLng? _userLocation;
  Position? _bestPosition;

  StreamSubscription<Position>? _locationSubscription;

  Timer? _locationRetryTimer;

  bool _isLoading = true;
  bool _locationError = false;
  bool _isGettingPreciseLocation = false;
  bool _precisePermission = false;

  String _locationStatus = 'Getting precise location...';

  double? _accuracyMeters;
  double? _altitudeMeters;
  double? _altitudeAccuracyMeters;

  String _floorText = 'Floor: Not available';

  // ============================================================
  // CROWD
  // ============================================================

  List<WeightedLatLng> _crowdPoints = [];

  String _crowdLevel = 'Loading...';

  int _density = 0;

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
    _locationRetryTimer?.cancel();

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
        _locationStatus = 'Checking precise location...';
      });
    }

    try {
      // ========================================================
      // LOCATION SERVICE
      // ========================================================

      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        _showLocationError(
          'GPS/location services are disabled. Please turn them on.',
        );
        return;
      }

      // ========================================================
      // PERMISSION
      // ========================================================

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _showLocationError('Location permission was denied.');
        return;
      }

      if (permission == LocationPermission.deniedForever) {
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

        _precisePermission = accuracyStatus == LocationAccuracyStatus.precise;
      } catch (e) {
        debugPrint('PRECISE LOCATION CHECK ERROR: $e');

        // Continue with high-accuracy requests if the
        // platform does not support the accuracy check.
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
          _locationStatus = 'Finding your most accurate GPS position...';
        });
      }

      for (int i = 0; i < 6; i++) {
        try {
          final Position position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.bestForNavigation,
              distanceFilter: 0,
              timeLimit: Duration(seconds: 15),
            ),
          );

          debugPrint(
            'GPS READING ${i + 1}: '
            '${position.latitude}, '
            '${position.longitude} '
            'accuracy=${position.accuracy}m',
          );

          // Keep the reading with the smallest reported
          // horizontal accuracy.
          if (bestPosition == null ||
              position.accuracy < bestPosition.accuracy) {
            bestPosition = position;
          }

          if (mounted) {
            setState(() {
              _locationStatus =
                  'Improving GPS accuracy... '
                  '±${position.accuracy.toStringAsFixed(1)} m';
            });
          }

          // A very good phone GPS result.
          if (position.accuracy <= 5) {
            break;
          }
        } on TimeoutException catch (e) {
          debugPrint('GPS READING TIMEOUT ${i + 1}: $e');
        } catch (e) {
          debugPrint('GPS READING ERROR ${i + 1}: $e');
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
          debugPrint('LAST KNOWN LOCATION ERROR: $e');
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

      await _updateLocation(bestPosition, moveMap: true);

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
      debugPrint('GPS MAIN TIMEOUT: $e');

      _showLocationError('GPS took too long to get an accurate location.');
    } catch (e) {
      debugPrint('GPS MAIN ERROR: $e');

      _showLocationError('Unable to get your current location.');
    }
  }

  // ============================================================
  // CONTINUOUS LOCATION TRACKING
  // ============================================================

  Future<void> _startLocationStream() async {
    await _locationSubscription?.cancel();

    _locationSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 5,
          ),
        ).listen(
          (Position position) async {
            await _updateLocation(position, moveMap: false);
          },
          onError: (Object error) {
            debugPrint('LOCATION STREAM ERROR: $error');
          },
        );
  }

  // ============================================================
  // APPLY LOCATION
  // ============================================================

  Future<void> _updateLocation(
    Position position, {
    bool moveMap = false,
  }) async {
    if (!mounted) return;

    // If we already have a much better reading, ignore a
    // significantly worse one.
    if (_bestPosition != null &&
        position.accuracy > _bestPosition!.accuracy + 20 &&
        position.accuracy > 30) {
      return;
    }

    _bestPosition = position;

    final LatLng currentLocation = LatLng(
      position.latitude,
      position.longitude,
    );

    // ========================================================
    // ACCURACY
    // ========================================================

    final double accuracy = position.accuracy;

    String accuracyText;

    if (accuracy <= 5) {
      accuracyText = 'Very accurate • ±${accuracy.toStringAsFixed(1)} m';
    } else if (accuracy <= 10) {
      accuracyText = 'High accuracy • ±${accuracy.toStringAsFixed(1)} m';
    } else if (accuracy <= 25) {
      accuracyText = 'Good accuracy • ±${accuracy.toStringAsFixed(1)} m';
    } else if (accuracy <= 50) {
      accuracyText = 'Moderate accuracy • ±${accuracy.toStringAsFixed(1)} m';
    } else {
      accuracyText = 'Low accuracy • ±${accuracy.toStringAsFixed(1)} m';
    }

    // ========================================================
    // ALTITUDE
    // ========================================================
    //
    // Your installed Geolocator API does not expose
    // Position.hasAltitude, so use altitude directly.
    // ========================================================

    final double? altitude = position.altitude;

    final double? altitudeAccuracy = position.altitudeAccuracy;

    // ========================================================
    // FLOOR
    // ========================================================

    final int? floor = position.floor;

    if (floor != null) {
      _floorText = 'Floor: ${_formatFloor(floor)}';

      MapCrowdScreen.latestFloor = floor;
    } else {
      _floorText = 'Floor: Not available';

      MapCrowdScreen.latestFloor = null;
    }

    // ========================================================
    // SAVE LATEST REAL LOCATION
    // ========================================================

    MapCrowdScreen.latestPosition = position;

    if (!mounted) return;

    setState(() {
      _userLocation = currentLocation;

      _bestPosition = position;

      _accuracyMeters = accuracy;

      _altitudeMeters = altitude;

      _altitudeAccuracyMeters = altitudeAccuracy;

      _locationStatus = accuracyText;

      _locationError = false;

      _isLoading = false;
    });

    // Keep the crowd visualization centered around the
    // user's actual current GPS position.
    _generateCrowdData(currentLocation);

    if (moveMap) {
      _mapController.move(currentLocation, 17.0);
    }
  }

  // ============================================================
  // FLOOR FORMAT
  // ============================================================

  String _formatFloor(int floor) {
    if (floor == 0) {
      return 'Ground';
    }

    if (floor == 1) {
      return '1st';
    }

    if (floor == 2) {
      return '2nd';
    }

    if (floor == 3) {
      return '3rd';
    }

    return '${floor}th';
  }

  // ============================================================
  // APPROXIMATE LOCATION WARNING
  // ============================================================

  void _showApproximateLocationDialog() {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Precise location is off'),
            content: const Text(
              'TrekCure has approximate location permission. For the best possible GPS accuracy, enable Precise Location in your device settings.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('Later'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);

                  Geolocator.openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          );
        },
      );
    });
  }

  // ============================================================
  // CROWD DATA
  // ============================================================
  //
  // IMPORTANT:
  // GPS location is real.
  // Crowd data below is still simulated.
  // ============================================================

  void _generateCrowdData(LatLng center) {
    final Random random = Random();

    final List<WeightedLatLng> points = [];

    double totalDensity = 0;

    for (int i = 0; i < 100; i++) {
      final double latitudeOffset = (random.nextDouble() - 0.5) * 0.05;

      final double longitudeOffset = (random.nextDouble() - 0.5) * 0.05;

      final double density = 0.1 + random.nextDouble() * 0.9;

      totalDensity += density;

      points.add(
        WeightedLatLng(
          LatLng(
            center.latitude + latitudeOffset,
            center.longitude + longitudeOffset,
          ),
          density,
        ),
      );
    }

    final double averageDensity = totalDensity / points.length;

    final int percentage = (averageDensity * 100).round();

    String level;

    if (percentage <= 30) {
      level = 'Low';
    } else if (percentage <= 70) {
      level = 'Moderate';
    } else {
      level = 'High';
    }

    if (!mounted) return;

    setState(() {
      _crowdPoints = points;

      _density = percentage;

      _crowdLevel = level;
    });
  }

  // ============================================================
  // REFRESH LOCATION
  // ============================================================

  Future<void> _refreshLocation() async {
    await _getLocation();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Location updated'),
        duration: Duration(seconds: 1),
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

    _mapController.move(_userLocation!, 18.0);
  }

  // ============================================================
  // LOCATION DETAILS
  // ============================================================

  void _showLocationDetails() {
    final Position? position = _bestPosition;

    if (position == null) {
      _showMessage('Location is not available yet.');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Precise GPS Location',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 18),

                _detailRow(
                  Icons.location_on,
                  'Latitude',
                  position.latitude.toStringAsFixed(7),
                ),

                _detailRow(
                  Icons.location_on,
                  'Longitude',
                  position.longitude.toStringAsFixed(7),
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

                if (_altitudeAccuracyMeters != null)
                  _detailRow(
                    Icons.vertical_align_center,
                    'Vertical accuracy',
                    '±${_altitudeAccuracyMeters!.toStringAsFixed(1)} m',
                  ),

                _detailRow(
                  Icons.layers_outlined,
                  'Floor',
                  _floorText.replaceFirst('Floor: ', ''),
                ),

                _detailRow(
                  Icons.meeting_room_outlined,
                  'Room',
                  'Not available from GPS',
                ),

                const SizedBox(height: 12),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.lightGreenBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'GPS can provide a highly accurate outdoor position, but it cannot reliably determine a specific room. Room-level positioning requires technologies such as BLE beacons, UWB, Wi-Fi fingerprinting, or a building indoor-positioning system.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textGrey,
                      height: 1.4,
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

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primaryGreen),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textGrey,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
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

  void _showLocationError(String message) {
    if (!mounted) return;

    setState(() {
      _isLoading = false;

      _isGettingPreciseLocation = false;

      _locationError = true;

      _locationStatus = 'Location unavailable';
    });

    _showMessage(message);
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Crowd Map',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),

        actions: [
          IconButton(
            onPressed: _refreshLocation,
            tooltip: 'Update location',
            icon: const Icon(Icons.my_location),
          ),

          IconButton(
            onPressed: _showLocationDetails,
            tooltip: 'Location details',
            icon: const Icon(Icons.info_outline),
          ),

          IconButton(
            onPressed: () {
              if (_userLocation == null) {
                _getLocation();
              } else {
                _generateCrowdData(_userLocation!);
              }
            },
            tooltip: 'Refresh crowd',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      body: Column(
        children: [
          _buildLocationCard(),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: _buildMap(),
              ),
            ),
          ),

          _buildLegend(),

          _buildCrowdCard(),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: _goToCurrentLocation,
        tooltip: 'My Location',
        child: const Icon(Icons.my_location),
      ),

      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }

  // ============================================================
  // LOCATION CARD
  // ============================================================

  Widget _buildLocationCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.lightGreenBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.gps_fixed,
                    color: AppColors.primaryGreen,
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current Location',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        _locationStatus,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                ),

                if (_precisePermission)
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.primaryGreen,
                    size: 20,
                  ),
              ],
            ),

            const SizedBox(height: 10),

            Text(
              _bestPosition == null
                  ? 'Waiting for GPS...'
                  : '${_bestPosition!.latitude.toStringAsFixed(7)}, '
                        '${_bestPosition!.longitude.toStringAsFixed(7)}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _miniLocationStat(
                    Icons.my_location,
                    'Accuracy',
                    _accuracyMeters == null
                        ? '--'
                        : '±${_accuracyMeters!.toStringAsFixed(1)} m',
                  ),
                ),

                Expanded(
                  child: _miniLocationStat(
                    Icons.layers_outlined,
                    'Floor',
                    _floorText.replaceFirst('Floor: ', ''),
                  ),
                ),

                Expanded(
                  child: _miniLocationStat(
                    Icons.height,
                    'Elevation',
                    _altitudeMeters == null
                        ? '--'
                        : '${_altitudeMeters!.toStringAsFixed(0)} m',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                const Icon(
                  Icons.meeting_room_outlined,
                  size: 15,
                  color: AppColors.textGrey,
                ),

                const SizedBox(width: 5),

                const Expanded(
                  child: Text(
                    'Room-level positioning requires indoor technology.',
                    style: TextStyle(fontSize: 10, color: AppColors.textGrey),
                  ),
                ),

                TextButton(
                  onPressed: _showLocationDetails,
                  child: const Text('Details', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MINI LOCATION STAT
  // ============================================================

  Widget _miniLocationStat(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.primaryGreen),

        const SizedBox(width: 4),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 9, color: AppColors.textGrey),
              ),

              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // MAP
  // ============================================================

  Widget _buildMap() {
    const LatLng defaultLocation = LatLng(19.0760, 72.8777);

    return FlutterMap(
      mapController: _mapController,

      options: MapOptions(
        initialCenter: _userLocation ?? defaultLocation,
        initialZoom: 17.0,
        minZoom: 5.0,
        maxZoom: 20.0,
      ),

      children: [
        // ======================================================
        // MAP TILES
        // ======================================================

        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.trekcure.app',
        ),

        // ======================================================
        // CROWD HEATMAP
        // ======================================================
        if (_crowdPoints.isNotEmpty)
          HeatMapLayer(
            heatMapDataSource: InMemoryHeatMapDataSource(data: _crowdPoints),
            heatMapOptions: HeatMapOptions(
              radius: 35,
              blurFactor: 0.8,
              minOpacity: 0.25,
              gradient: {
                0.0: Colors.green,
                0.35: Colors.yellow,
                0.60: Colors.orange,
                1.0: Colors.red,
              },
            ),
          ),

        // ======================================================
        // REAL USER LOCATION MARKER
        // ======================================================
        if (_userLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _userLocation!,
                width: 70,
                height: 70,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                    ),

                    const Icon(Icons.location_on, color: Colors.blue, size: 38),
                  ],
                ),
              ),
            ],
          ),

        // ======================================================
        // LOADING
        // ======================================================
        if (_isLoading) const Center(child: CircularProgressIndicator()),

        // ======================================================
        // ERROR
        // ======================================================
        if (_locationError)
          Center(
            child: Container(
              margin: const EdgeInsets.all(30),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(blurRadius: 10, color: Colors.black26),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_off, size: 40, color: Colors.red),

                  const SizedBox(height: 10),

                  const Text(
                    'Location unavailable',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),

                  const SizedBox(height: 10),

                  ElevatedButton(
                    onPressed: _getLocation,
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // LEGEND
  // ============================================================

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLegendItem(Colors.green, 'Low'),

          const SizedBox(width: 22),

          _buildLegendItem(Colors.orange, 'Moderate'),

          const SizedBox(width: 22),

          _buildLegendItem(Colors.red, 'High'),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),

        const SizedBox(width: 6),

        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
        ),
      ],
    );
  }

  // ============================================================
  // CROWD CARD
  // ============================================================

  Widget _buildCrowdCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Crowd Overview',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Text(
              _userLocation == null
                  ? 'Getting your current location...'
                  : 'Crowd density around your current location.',
              style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: _buildCrowdInfo(
                    Icons.groups,
                    _crowdLevel,
                    'Current Crowd',
                    _getCrowdColor(),
                  ),
                ),

                Container(width: 1, height: 45, color: Colors.grey),

                Expanded(
                  child: _buildCrowdInfo(
                    Icons.percent,
                    '$_density%',
                    'Density',
                    _getCrowdColor(),
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
  // CROWD INFO
  // ============================================================

  Widget _buildCrowdInfo(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 23),

        const SizedBox(height: 5),

        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 14,
          ),
        ),

        const SizedBox(height: 2),

        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, color: AppColors.textGrey),
        ),
      ],
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
