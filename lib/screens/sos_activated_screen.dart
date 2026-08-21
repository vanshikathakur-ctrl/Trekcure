import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SosActivatedScreen extends StatelessWidget {
  const SosActivatedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('SOS Activated',
            style: TextStyle(
                color: AppColors.dangerRed,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(
                  color: AppColors.dangerRed, shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 44),
            ),
            const SizedBox(height: 20),
            const Text('SOS ACTIVATED!',
                style: TextStyle(
                    color: AppColors.dangerRed,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text(
              'Your emergency alert\nis being sent...',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textGrey),
            ),
            const SizedBox(height: 28),
            _statusRow('Location Shared', 'Your location is shared with contacts'),
            const SizedBox(height: 14),
            _statusRow('Contacts Notified',
                '2 emergency contacts\nhave been notified'),
            const SizedBox(height: 14),
            _statusRow('Help is on the way',
                'Stay calm, help will\nreach you soon.'),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  side: const BorderSide(color: AppColors.dangerRed),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Cancel SOS',
                    style: TextStyle(color: AppColors.dangerRed)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusRow(String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle, color: AppColors.primaryGreen, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(subtitle,
                  style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
            ],
          ),
        ),
      ],
    );
  }
}
