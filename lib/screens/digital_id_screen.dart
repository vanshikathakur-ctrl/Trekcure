import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import 'package:trekcure/services/trekcure_api_service.dart';

class DigitalIdScreen extends StatefulWidget {
  const DigitalIdScreen({super.key});

  @override
  State<DigitalIdScreen> createState() => _DigitalIdScreenState();
}

class _DigitalIdScreenState extends State<DigitalIdScreen> {
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _credential;
  String? _touristId;
  String? _credentialHash;

  String _userName = '';
  String _userId = '';

  @override
  void initState() {
    super.initState();
    _createDigitalId();
  }

  // ============================================================
  // CREATE DIGITAL ID
  // ============================================================

  Future<void> _createDigitalId() async {
    setState(() {
      _loading = true;
      _error = null;
      _credential = null;
      _touristId = null;
      _credentialHash = null;
    });

    try {
      // ----------------------------------------------------------
      // GET CURRENT SUPABASE USER
      // ----------------------------------------------------------

      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        throw Exception('Please log in before creating a Digital ID.');
      }

      _userId = user.id;

      // ----------------------------------------------------------
      // GET USER NAME
      // ----------------------------------------------------------

      String name = 'Traveler';

      final metadata = user.userMetadata;

      if (metadata != null) {
        final metadataName = metadata['full_name'] ?? metadata['name'];

        if (metadataName != null &&
            metadataName.toString().trim().isNotEmpty) {
          name = metadataName.toString().trim();
        }
      }

      _userName = name;

      // ----------------------------------------------------------
      // GET AGE
      // ----------------------------------------------------------

      int age = 18;

      if (metadata != null && metadata['age'] != null) {
        age = int.tryParse(metadata['age'].toString()) ?? 18;
      }

      // ----------------------------------------------------------
      // CALL FASTAPI BACKEND
      // ----------------------------------------------------------

      final data = await TrekCureApiService.createDigitalId(
        userId: user.id,
        name: name,
        age: age,
      );

      if (!mounted) return;

      // ----------------------------------------------------------
      // SAVE RESPONSE
      // ----------------------------------------------------------

      setState(() {
        _touristId = data['tourist_id']?.toString();

        _credential = data['credential'] != null
            ? Map<String, dynamic>.from(data['credential'])
            : null;

        // Hash is returned at the TOP LEVEL by FastAPI
        _credentialHash = data['hash']?.toString();

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Could not create Digital ID.\n\n$e';
        _loading = false;
      });
    }
  }

  // ============================================================
  // CREATE QR DATA
  // ============================================================

  String _createQrData() {
    final issuedDate = _credential?['issued_date'] ?? '';
    final validUntil = _credential?['valid_until'] ?? '';
    final hash = _credentialHash ?? '';

    final qrData = {
      'app': 'TrekCure',
      'type': 'Digital Travel ID',
      'tourist_id': _touristId ?? '',
      'user_id': _userId,
      'name': _userName,
      'issued_date': issuedDate,
      'valid_until': validUntil,
      'credential_hash': hash,
    };

    return jsonEncode(qrData);
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text(
          'Digital Travel ID',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _createDigitalId,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _buildBody(),
      ),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Creating Digital Travel ID...',
              style: TextStyle(color: AppColors.textGrey),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return _buildError();
    }

    if (_touristId == null || _credential == null) {
      return const Center(
        child: Text('Digital ID data is unavailable.'),
      );
    }

    return _buildDigitalId();
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline,
            color: AppColors.dangerRed,
            size: 50,
          ),
          const SizedBox(height: 12),
          const Text(
            'Unable to create Digital ID',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _error ?? 'Unknown error',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textGrey,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _createDigitalId,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DIGITAL ID CARD
  // ============================================================

  Widget _buildDigitalId() {
    final issuedDate = _credential?['issued_date'] ?? '—';
    final validUntil = _credential?['valid_until'] ?? '—';
    final hash = _credentialHash ?? '—';

    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Row(
                  children: const [
                    Text(
                      'Verified Traveler',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    Spacer(),
                    Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 18,
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _touristId ?? '—',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _userName,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Container(
                  height: 190,
                  width: 190,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: QrImageView(
                    data: _createQrData(),
                    version: QrVersions.auto,
                    size: 170,
                    backgroundColor: Colors.white,
                    errorCorrectionLevel: QrErrorCorrectLevel.H,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  'Scan to verify traveler identity',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),

                const SizedBox(height: 18),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Issued on : $issuedDate',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        'Valid till : $validUntil',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Traveler Information',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.person,
                  label: 'Name',
                  value: _userName,
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.badge,
                  label: 'Tourist ID',
                  value: _touristId ?? '—',
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          AppCard(
            color: AppColors.infoBgLight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.link,
                  color: AppColors.infoBlue,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Blockchain Credential',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'This Digital ID is secured with a SHA-256 credential hash generated by the TrekCure backend.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textGrey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        hash,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// INFORMATION ROW
// ================================================================

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: AppColors.infoBlue,
        ),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textGrey,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}