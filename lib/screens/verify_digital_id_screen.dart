import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/trekcure_api_service.dart';
import '../theme/app_theme.dart';

class VerifyDigitalIdScreen extends StatefulWidget {
  const VerifyDigitalIdScreen({super.key});

  @override
  State<VerifyDigitalIdScreen> createState() =>
      _VerifyDigitalIdScreenState();
}

class _VerifyDigitalIdScreenState extends State<VerifyDigitalIdScreen> {
  bool _isProcessing = false;
  bool _showScanner = true;

  String? _error;
  Map<String, dynamic>? _verificationResult;

  // ============================================================
  // HANDLE QR SCAN
  // ============================================================

  Future<void> _handleScan(String rawValue) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _showScanner = false;
      _error = null;
      _verificationResult = null;
    });

    try {
      // Decode QR JSON
      final decodedData = jsonDecode(rawValue);

      if (decodedData is! Map<String, dynamic>) {
        throw Exception('Invalid QR code format.');
      }

      // Check if this is a TrekCure Digital ID
      if (decodedData['app'] != 'TrekCure' ||
          decodedData['type'] != 'Digital Travel ID') {
        throw Exception(
          'This is not a valid TrekCure Digital Travel ID.',
        );
      }

      final userId = decodedData['user_id'];
      final credentialData = decodedData['credential'];

      if (userId == null || credentialData == null) {
        throw Exception(
          'The QR code does not contain complete identity information.',
        );
      }

      if (credentialData is! Map) {
        throw Exception('Invalid credential format.');
      }

      // Convert scanned credential into Map<String, dynamic>
      final credential =
          Map<String, dynamic>.from(credentialData);

      // Send to backend for verification
      final result = await TrekCureApiService.verifyDigitalId(
        userId: userId.toString(),
        credential: credential,
      );

      if (!mounted) return;

      setState(() {
        _verificationResult = result;
        _isProcessing = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _isProcessing = false;
      });
    }
  }

  // ============================================================
  // SCAN AGAIN
  // ============================================================

  void _scanAgain() {
    setState(() {
      _isProcessing = false;
      _showScanner = true;
      _error = null;
      _verificationResult = null;
    });
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
          'Verify Digital ID',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: _showScanner
          ? _buildScanner()
          : _buildResult(),
    );
  }

  // ============================================================
  // QR SCANNER
  // ============================================================

  Widget _buildScanner() {
    return Stack(
      children: [
        MobileScanner(
          onDetect: (capture) {
            if (_isProcessing) return;

            final barcode = capture.barcodes.firstOrNull;

            if (barcode == null) return;

            final rawValue = barcode.rawValue;

            if (rawValue == null) return;

            _handleScan(rawValue);
          },
        ),

        // Scanner overlay
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white,
                width: 3,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),

        Positioned(
          left: 24,
          right: 24,
          bottom: 50,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'Point your camera at a TrekCure Digital Travel ID QR code',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // RESULT
  // ============================================================

  Widget _buildResult() {
    if (_isProcessing) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Verifying Digital ID...',
              style: TextStyle(
                color: AppColors.textGrey,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return _buildErrorResult();
    }

    if (_verificationResult == null) {
      return const Center(
        child: Text('No verification result available.'),
      );
    }

    final verified = _verificationResult!['verified'] == true;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              verified
                  ? Icons.verified
                  : Icons.cancel,
              size: 80,
              color: verified
                  ? AppColors.primaryGreen
                  : AppColors.dangerRed,
            ),

            const SizedBox(height: 20),

            Text(
              verified
                  ? 'Identity Verified'
                  : 'Identity Not Verified',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            Text(
              _verificationResult!['message']?.toString() ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textGrey,
              ),
            ),

            const SizedBox(height: 30),

            ElevatedButton.icon(
              onPressed: _scanAgain,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Another ID'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ERROR RESULT
  // ============================================================

  Widget _buildErrorResult() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 70,
              color: AppColors.dangerRed,
            ),

            const SizedBox(height: 20),

            const Text(
              'Unable to Verify ID',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textGrey,
              ),
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: _scanAgain,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}