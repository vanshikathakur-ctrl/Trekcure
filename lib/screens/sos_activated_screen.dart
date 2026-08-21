import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';

class SosActivatedScreen extends StatefulWidget {
  final String? sosId;

  const SosActivatedScreen({
    super.key,
    this.sosId,
  });

  @override
  State<SosActivatedScreen> createState() => _SosActivatedScreenState();
}

class _SosActivatedScreenState extends State<SosActivatedScreen> {
  bool _isCancelling = false;

  Future<void> _cancelSos() async {
    // If this is an offline/demo SOS, there is no database record to cancel.
    if (widget.sosId == null) {
      if (mounted) {
        Navigator.pop(context);
      }
      return;
    }

    setState(() {
      _isCancelling = true;
    });

    try {
      await Supabase.instance.client
          .from('sos_alerts')
          .update({
            'status': 'cancelled',
          })
          .eq('id', widget.sosId!);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SOS cancelled successfully'),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel SOS: $e'),
          backgroundColor: AppColors.dangerRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCancelling = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text(
          'SOS Activated',
          style: TextStyle(
            color: AppColors.dangerRed,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
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
                color: AppColors.dangerRed,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 44,
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'SOS ACTIVATED!',
              style: TextStyle(
                color: AppColors.dangerRed,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              widget.sosId == null
                  ? 'Your emergency alert has been activated.'
                  : 'Your emergency alert\nis being sent...',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textGrey,
              ),
            ),

            const SizedBox(height: 28),

            const _StatusRow(
              title: 'Location Shared',
              subtitle: 'Mumbai location is shared for this prototype',
            ),

            const SizedBox(height: 14),

            const _StatusRow(
              title: 'Emergency Alert Active',
              subtitle: 'Your SOS request has been recorded',
            ),

            const SizedBox(height: 14),

            const _StatusRow(
              title: 'Help is on the way',
              subtitle: 'Stay calm and wait for assistance.',
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isCancelling ? null : _cancelSos,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  side: const BorderSide(
                    color: AppColors.dangerRed,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isCancelling
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Cancel SOS',
                        style: TextStyle(
                          color: AppColors.dangerRed,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String title;
  final String subtitle;

  const _StatusRow({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.check_circle,
          color: AppColors.primaryGreen,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textGrey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}