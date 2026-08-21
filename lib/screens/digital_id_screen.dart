import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _createDigitalId();
  }

  Future<void> _createDigitalId() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        throw Exception('Please log in before creating a Digital ID.');
      }

      final data = await TrekCureApiService.createDigitalId(
        userId: user.id,
        name: 'Ananya Sharma',
        age: 22,
      );

      setState(() {
        _touristId = data['tourist_id'];
        _credential = data['credential'];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not create Digital ID.\n$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text(
          'Digital Travel ID',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _createDigitalId,
          ),
        ],
      ),
      body: Padding(padding: const EdgeInsets.all(16), child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: AppColors.dangerRed,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textGrey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _createDigitalId,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final issuedDate = _credential?['issued_date'] ?? '—';

    final validUntil = _credential?['valid_until'] ?? '—';

    return Column(
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
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  Spacer(),
                  Icon(Icons.check_circle, color: Colors.white, size: 18),
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

              const SizedBox(height: 20),

              Container(
                height: 170,
                width: 170,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.qr_code_2,
                  size: 130,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 18),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Issued on : $issuedDate',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  Text(
                    'Valid till : $validUntil',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        AppCard(
          color: AppColors.infoBgLight,
          child: Row(
            children: const [
              Icon(Icons.link, color: AppColors.infoBlue),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'This is your digital identity, secured with a SHA-256 credential hash generated by the TrekCure backend.',
                  style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
