import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_mesh_network/flutter_mesh_network.dart';
import 'package:permission_handler/permission_handler.dart';

class MeshService {
  MeshService._();

  static final MeshService instance = MeshService._();

  // ============================================================
  // MESH NETWORK
  // ============================================================

  final MeshNetwork _mesh = MeshNetwork(
    config: const MeshConfig(
      serviceName: 'trekcure-mesh',
      strategy: TransportStrategy.lowPower,
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
  StreamSubscription? _messageSubscription;

  final Set<String> _discoveredNodes = {};

  int _nearbyNodeCount = 0;
  bool _isRunning = false;

  String? _userId;
  String? _userName;

  DateTime? _lastSosSentAt;

  int get nearbyNodeCount => _nearbyNodeCount;

  bool get isRunning => _isRunning;

  // ============================================================
  // CREATE DEVICE ID
  // ============================================================

  String _createDeviceId() {
    final random = Random();

    return 'tc_${100000 + random.nextInt(900000)}';
  }

  // ============================================================
  // REQUEST PERMISSIONS
  // ============================================================

  Future<bool> _requestMeshPermissions() async {
    final permissions = [
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.location,
      Permission.nearbyWifiDevices,
    ];

    final statuses = await permissions.request();

    debugPrint('==============================');
    debugPrint('MESH PERMISSION STATUS');
    debugPrint('==============================');

    for (final entry in statuses.entries) {
      debugPrint('${entry.key}: ${entry.value}');
    }

    final bluetoothScan =
        statuses[Permission.bluetoothScan]?.isGranted ?? false;

    final bluetoothAdvertise =
        statuses[Permission.bluetoothAdvertise]?.isGranted ?? false;

    final bluetoothConnect =
        statuses[Permission.bluetoothConnect]?.isGranted ?? false;

    final location =
        statuses[Permission.location]?.isGranted ?? false;

    final granted =
        bluetoothScan &&
        bluetoothAdvertise &&
        bluetoothConnect &&
        location;

    debugPrint('Required permissions granted: $granted');
    debugPrint('==============================');

    return granted;
  }

  // ============================================================
  // UPDATE NODE COUNT
  // ============================================================

  void _updateNodeCount() {
    _nearbyNodeCount = _mesh.onlineNodeCount;

    debugPrint('==============================');
    debugPrint('MESH NODE STATUS');
    debugPrint('Local device: $_userName');
    debugPrint('Online nodes: $_nearbyNodeCount');

    debugPrint(
      'Tracked nodes: '
      '${_discoveredNodes.isEmpty ? "NONE" : _discoveredNodes.join(", ")}',
    );

    debugPrint('==============================');

    if (!_nodeCountController.isClosed) {
      _nodeCountController.add(_nearbyNodeCount);
    }
  }

  // ============================================================
  // START MESH
  // ============================================================

  Future<void> start() async {
    if (_isRunning) {
      debugPrint('Mesh is already running');
      debugPrint('Local device: $_userName');
      debugPrint('Nearby nodes: $_nearbyNodeCount');

      _updateNodeCount();
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
          'Required mesh permissions were not granted',
        );
      }

      // Create identity.
      _userId ??= _createDeviceId();

      final suffix =
          _userId!.substring(_userId!.length - 4);

      _userName ??= 'TrekCure-$suffix';

      debugPrint('==============================');
      debugPrint('LOCAL MESH IDENTITY');
      debugPrint('User ID: $_userId');
      debugPrint('User name: $_userName');
      debugPrint('==============================');

      _discoveredNodes.clear();

      // ==========================================================
      // NODE LISTENER
      // ==========================================================

      await _nodeSubscription?.cancel();

      _nodeSubscription =
          _mesh.onNodeChanged.listen((MeshNode node) {
        final nodeName = node.name.toString();

        debugPrint('==============================');
        debugPrint('MESH NODE EVENT');
        debugPrint('Local device: $_userName');
        debugPrint('Detected node: $nodeName');

        debugPrint(
          'Package online count: ${_mesh.onlineNodeCount}',
        );

        debugPrint('Node online: ${node.isOnline()}');

        debugPrint('==============================');

        // Ignore our own device.
        if (nodeName == _userName) {
          debugPrint('Ignoring local device.');
          return;
        }

        // Add or remove device depending on its state.
        if (node.isOnline()) {
          _discoveredNodes.add(nodeName);

          debugPrint(
            'DEVICE DISCOVERED: $nodeName',
          );
        } else {
          _discoveredNodes.remove(nodeName);

          debugPrint(
            'DEVICE LEFT/OFFLINE: $nodeName',
          );
        }

        _updateNodeCount();
      });

      // ==========================================================
      // MESSAGE LISTENER
      // ==========================================================

      await _messageSubscription?.cancel();

      _messageSubscription =
          _mesh.onMessage.listen((msg) {
        final payload = msg.payload.toString();

        final senderName =
            msg.senderName.toString();

        debugPrint('==============================');
        debugPrint('MESH MESSAGE EVENT');
        debugPrint('Local device: $_userName');
        debugPrint('Local ID: $_userId');
        debugPrint('Sender: $senderName');
        debugPrint('Payload: $payload');
        debugPrint('==============================');

        // Ignore our own messages.
        if (senderName == _userName) {
          debugPrint(
            'Ignoring own message echoed by mesh.',
          );
          return;
        }

        // Prevent immediate local SOS echo.
        final lastSent = _lastSosSentAt;

        if (lastSent != null) {
          final difference =
              DateTime.now().difference(lastSent);

          if (difference.inSeconds < 2 &&
              payload.toLowerCase().contains('sos')) {
            debugPrint(
              'Ignoring possible local SOS echo.',
            );
            return;
          }
        }

        // Handle SOS.
        if (payload.toLowerCase().contains('sos')) {
          debugPrint('==============================');
          debugPrint('REMOTE SOS RECEIVED');
          debugPrint('From: $senderName');
          debugPrint('On device: $_userName');
          debugPrint('==============================');

          if (!_sosController.isClosed) {
            _sosController.add({
              'senderName': senderName,
              'payload': payload,
              'receivedAt':
                  DateTime.now().toIso8601String(),
            });
          }
        }
      });

      // ==========================================================
      // START NETWORK
      // ==========================================================

      await _mesh.start(
        userId: _userId!,
        userName: _userName!,
      );

      _isRunning = _mesh.isRunning;

      _updateNodeCount();

      debugPrint('==============================');
      debugPrint('MESH STARTED SUCCESSFULLY');
      debugPrint('User ID: $_userId');
      debugPrint('User name: $_userName');
      debugPrint('Running: $_isRunning');

      debugPrint(
        'Online nodes: ${_mesh.onlineNodeCount}',
      );

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

      _discoveredNodes.clear();

      _nearbyNodeCount = 0;

      if (!_nodeCountController.isClosed) {
        _nodeCountController.add(0);
      }

      debugPrint('==============================');
      debugPrint('MESH SERVICE STOPPED');
      debugPrint('Local device: $_userName');
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
      throw Exception(
        'Offline mesh is not running',
      );
    }

    _lastSosSentAt = DateTime.now();

    debugPrint('==============================');
    debugPrint('OFFLINE SOS BROADCAST');
    debugPrint('Sender device: $_userName');
    debugPrint('Sender ID: $_userId');
    debugPrint('Message: $message');

    debugPrint(
      'Online peers: ${_mesh.onlineNodeCount}',
    );

    debugPrint('==============================');

    await _mesh.sendSos(
      latitude: latitude ?? 0.0,
      longitude: longitude ?? 0.0,
    );

    debugPrint('==============================');
    debugPrint('SOS SENT THROUGH TREKCURE MESH');
    debugPrint('From: $_userName');
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