import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_mesh_network/flutter_mesh_network.dart';
import 'package:permission_handler/permission_handler.dart';

class MeshService {
  MeshService._();

  static final MeshService instance = MeshService._();

  final MeshNetwork _mesh = MeshNetwork(
    config: const MeshConfig(
      serviceName: 'TC',
      strategy: TransportStrategy.maxPerformance,
      enableLogging: true,
    ),
  );

  // ============================================================
  // NODE COUNT STREAM
  // ============================================================

  final StreamController<int> _nodeCountController =
      StreamController<int>.broadcast();

  Stream<int> get nodeCountStream => _nodeCountController.stream;

  // ============================================================
  // INCOMING SOS STREAM
  // ============================================================

  final StreamController<Map<String, dynamic>> _sosController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get sosStream => _sosController.stream;

  StreamSubscription<MeshNode>? _nodeSubscription;

  // Generic because the package message type is internal to the package.
  StreamSubscription? _messageSubscription;

  int _nearbyNodeCount = 0;
  bool _isRunning = false;

  int get nearbyNodeCount => _nearbyNodeCount;
  bool get isRunning => _isRunning;

  // ============================================================
  // PERMISSIONS
  // ============================================================

  Future<bool> _requestMeshPermissions() async {
    final permissions = [
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.location,
    ];

    final statuses = await permissions.request();

    final allGranted =
        statuses.values.every((status) => status.isGranted);

    debugPrint('==============================');
    debugPrint('MESH PERMISSION STATUS');
    debugPrint('==============================');

    for (final entry in statuses.entries) {
      debugPrint('${entry.key}: ${entry.value}');
    }

    debugPrint('All permissions granted: $allGranted');
    debugPrint('==============================');

    return allGranted;
  }

  // ============================================================
  // START MESH
  // ============================================================

  Future<void> start() async {
    if (_isRunning) {
      debugPrint('Mesh is already running');
      return;
    }

    try {
      debugPrint('==============================');
      debugPrint('STARTING TREKCURE MESH');
      debugPrint('==============================');

      final permissionsGranted =
          await _requestMeshPermissions();

      if (!permissionsGranted) {
        throw Exception(
          'Required Bluetooth permissions were not granted',
        );
      }

      // ----------------------------------------------------------
      // NODE LISTENER
      // ----------------------------------------------------------

      await _nodeSubscription?.cancel();

      _nodeSubscription =
          _mesh.onNodeChanged.listen((MeshNode node) {
        _nearbyNodeCount = _mesh.onlineNodeCount;

        debugPrint('==============================');
        debugPrint('MESH NODE DETECTED');
        debugPrint('Node name: ${node.name}');
        debugPrint('Online nodes: $_nearbyNodeCount');
        debugPrint('==============================');

        if (!_nodeCountController.isClosed) {
          _nodeCountController.add(_nearbyNodeCount);
        }
      });

      // ----------------------------------------------------------
      // START THE NETWORK
      // ----------------------------------------------------------

      final userId =
          'tc${DateTime.now().millisecondsSinceEpoch % 100000}';

      await _mesh.start(
        userId: userId,
        userName: 'TC',
      );

      _isRunning = _mesh.isRunning;

      // ----------------------------------------------------------
      // LISTEN FOR INCOMING MESSAGES
      // ----------------------------------------------------------

      await _messageSubscription?.cancel();

      _messageSubscription = _mesh.onMessage.listen((msg) {
        debugPrint('==============================');
        debugPrint('MESH MESSAGE RECEIVED');
        debugPrint('From: ${msg.senderName}');
        debugPrint('Payload: ${msg.payload}');
        debugPrint('==============================');

        // Detect SOS messages.
        //
        // The package may encode sendSos() internally.
        // We print the payload first so we can see its format.
        final payload = msg.payload.toString();

        if (payload.toLowerCase().contains('sos')) {
          debugPrint('🚨 INCOMING SOS DETECTED');

          if (!_sosController.isClosed) {
            _sosController.add({
              'senderName': msg.senderName.toString(),
              'payload': payload,
            });
          }
        }
      });

      _nearbyNodeCount = _mesh.onlineNodeCount;

      if (!_nodeCountController.isClosed) {
        _nodeCountController.add(_nearbyNodeCount);
      }

      debugPrint('==============================');
      debugPrint('MESH STARTED SUCCESSFULLY');
      debugPrint('User ID: $userId');
      debugPrint('Nearby nodes: $_nearbyNodeCount');
      debugPrint('==============================');
    } catch (e) {
      _isRunning = false;

      debugPrint('==============================');
      debugPrint('MESH START ERROR');
      debugPrint('$e');
      debugPrint('==============================');

      rethrow;
    }
  }

  // ============================================================
  // STOP MESH
  // ============================================================

  Future<void> stop() async {
    try {
      await _nodeSubscription?.cancel();
      _nodeSubscription = null;

      await _messageSubscription?.cancel();
      _messageSubscription = null;

      await _mesh.stop();

      _isRunning = false;
      _nearbyNodeCount = 0;

      if (!_nodeCountController.isClosed) {
        _nodeCountController.add(0);
      }

      debugPrint('==============================');
      debugPrint('MESH SERVICE STOPPED');
      debugPrint('==============================');
    } catch (e) {
      debugPrint('MESH STOP ERROR: $e');
    }
  }

  // ============================================================
  // SEND OFFLINE SOS
  // ============================================================

  Future<void> broadcastSos({
    required String message,
    double? latitude,
    double? longitude,
  }) async {
    if (!_isRunning) {
      throw Exception('Offline mesh is not running');
    }

    debugPrint('==============================');
    debugPrint('OFFLINE SOS BROADCAST');
    debugPrint('Message: $message');
    debugPrint('Latitude: $latitude');
    debugPrint('Longitude: $longitude');
    debugPrint('Nearby nodes: $_nearbyNodeCount');
    debugPrint('==============================');

    await _mesh.sendSos(
      latitude: latitude ?? 0.0,
      longitude: longitude ?? 0.0,
    );

    debugPrint('==============================');
    debugPrint('SOS SENT THROUGH TREKCURE MESH');
    debugPrint('==============================');
  }

  // ============================================================
  // CLEANUP
  // ============================================================

  Future<void> dispose() async {
    await stop();

    if (!_nodeCountController.isClosed) {
      await _nodeCountController.close();
    }

    if (!_sosController.isClosed) {
      await _sosController.close();
    }
  }
}