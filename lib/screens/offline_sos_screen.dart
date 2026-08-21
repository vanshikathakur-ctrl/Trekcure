import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'sos_activated_screen.dart';

class OfflineSosScreen extends StatelessWidget {
  const OfflineSosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('OFFLINE SOS',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.info_outline),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.wifi_off, color: AppColors.textGrey, size: 18),
                SizedBox(width: 6),
                Text('Works Without Internet',
                    style: TextStyle(
                        color: AppColors.textGrey,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 32),
            // Mesh network illustration
            SizedBox(
              height: 220,
              width: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.lightGreenBg,
                    ),
                  ),
                  Container(
                    width: 70,
                    height: 70,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryGreen,
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(Icons.phone, color: Colors.white, size: 28),
                  ),
                  Positioned(
                      top: 10,
                      left: 60,
                      child: _personDot()),
                  Positioned(top: 10, right: 60, child: _personDot()),
                  Positioned(bottom: 10, left: 30, child: _personDot()),
                  Positioned(bottom: 10, right: 30, child: _personDot()),
                ],
              ),
            ),
            const SizedBox(height: 32),
            AppCard(
              color: AppColors.lightGreenBg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.check_circle, color: AppColors.primaryGreen, size: 18),
                      SizedBox(width: 6),
                      Text('Offline Mode Active',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Using Nearby Connections to send SOS to people around you.',
                    style: TextStyle(color: AppColors.textGrey, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SosActivatedScreen())),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.dangerRed),
                child: const Text('Send Offline SOS'),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Hold for 3 Seconds',
                style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
          ],
        ),
      ),
    );
  }

  Widget _personDot() {
    return Container(
      width: 34,
      height: 34,
      decoration: const BoxDecoration(
          color: AppColors.primaryGreen, shape: BoxShape.circle),
      child: const Icon(Icons.person, color: Colors.white, size: 18),
    );
  }
}
