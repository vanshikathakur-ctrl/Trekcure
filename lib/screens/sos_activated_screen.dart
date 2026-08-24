import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/mesh_service.dart';
import '../theme/app_theme.dart';

class SosActivatedScreen extends StatefulWidget {
  final String? sosId;

  const SosActivatedScreen({super.key, this.sosId});

  @override
  State<SosActivatedScreen> createState() => _SosActivatedScreenState();
}

class _SosActivatedScreenState extends State<SosActivatedScreen> {
  bool _isCancelling = false;

  final MeshService _meshService = MeshService.instance;

  // ============================================================
  // CHECK IF THIS IS AN OFFLINE SOS
  //
  // Offline SOS IDs are generated like:
  //
  // offline_1234567890_1234
  // ============================================================

  bool get _isOfflineSos {
    final sosId = widget.sosId;

    return sosId == null ||
        sosId.isEmpty ||
        sosId == 'offline-demo' ||
        sosId.startsWith('offline_');
  }

  // ============================================================
  // CANCEL SOS
  // ============================================================

  Future<void> _cancelSos() async {
    if (_isCancelling) {
      return;
    }

    final String? reason = await _showCancellationReasonDialog();

    if (reason == null || reason.trim().isEmpty) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isCancelling = true;
    });

    try {
      // ==========================================================
      // OFFLINE SOS CANCELLATION
      // ==========================================================

      if (_isOfflineSos) {
        debugPrint('');
        debugPrint('================================');
        debugPrint('CANCELLING OFFLINE SOS');
        debugPrint('SOS ID: ${widget.sosId}');
        debugPrint('Reason: $reason');
        debugPrint(
          'Connected devices: '
          '${_meshService.nearbyNodeCount}',
        );
        debugPrint('================================');
        debugPrint('');

        if (!_meshService.isRunning) {
          throw Exception(
            'Offline mesh is no longer active. '
            'Unable to notify nearby devices.',
          );
        }

        await _meshService.broadcastSosCancellation(
          sosId: widget.sosId ?? 'offline-demo',
          reason: reason,
        );

        debugPrint('');
        debugPrint('================================');
        debugPrint('OFFLINE SOS CANCELLED SUCCESSFULLY');
        debugPrint('SOS ID: ${widget.sosId}');
        debugPrint('Reason: $reason');
        debugPrint(
          'Nearby devices notified: '
          '${_meshService.nearbyNodeCount}',
        );
        debugPrint('================================');
        debugPrint('');

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Offline SOS cancelled. Nearby devices notified.\nReason: $reason',
            ),
            backgroundColor: AppColors.primaryGreen,
          ),
        );

        Navigator.pop(context);
        return;
      }

      // ==========================================================
      // ONLINE SOS CANCELLATION
      // ==========================================================

      if (widget.sosId == null || widget.sosId!.trim().isEmpty) {
        throw Exception('Invalid SOS ID.');
      }

      debugPrint('');
      debugPrint('================================');
      debugPrint('CANCELLING ONLINE SOS');
      debugPrint('SOS ID: ${widget.sosId}');
      debugPrint('Reason: $reason');
      debugPrint('================================');
      debugPrint('');

      await Supabase.instance.client
          .from('sos_alerts')
          .update({
            'status': 'cancelled',
            'cancellation_reason': reason,
            'cancelled_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.sosId!);

      // The database update is the source of truth.
      // Supabase Realtime handles the in-app cancellation
      // notification. This FCM call handles push notification.
      try {
        final response = await Supabase.instance.client.functions.invoke(
          'send-sos-notification',
          body: {'sosId': widget.sosId, 'type': 'cancelled', 'reason': reason},
        );

        debugPrint(
          'SOS cancellation notification response: '
          '${response.data}',
        );
      } catch (notificationError) {
        // Do not treat a push-notification failure as a
        // cancellation failure. The SOS is already cancelled
        // in Supabase and Realtime can still notify the other user.
        debugPrint(
          'FCM cancellation notification failed: '
          '$notificationError',
        );
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('SOS cancelled successfully.\nReason: $reason'),
          backgroundColor: AppColors.primaryGreen,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      debugPrint('');
      debugPrint('================================');
      debugPrint('FAILED TO CANCEL SOS');
      debugPrint('SOS ID: ${widget.sosId}');
      debugPrint('Error: $e');
      debugPrint('================================');
      debugPrint('');

      if (!mounted) {
        return;
      }

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

  // ============================================================
  // CANCELLATION REASON DIALOG
  // ============================================================

  Future<String?> _showCancellationReasonDialog() async {
    String? selectedReason;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Cancel SOS',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Why are you cancelling the SOS?'),
                  ),
                  const SizedBox(height: 12),

                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Issue resolved'),
                    value: 'Issue resolved',
                    groupValue: selectedReason,
                    onChanged: (value) {
                      setDialogState(() {
                        selectedReason = value;
                      });
                    },
                  ),

                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('False alarm'),
                    value: 'False alarm',
                    groupValue: selectedReason,
                    onChanged: (value) {
                      setDialogState(() {
                        selectedReason = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Keep SOS Active'),
                ),
                ElevatedButton(
                  onPressed: selectedReason == null
                      ? null
                      : () {
                          Navigator.pop(dialogContext, selectedReason);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.dangerRed,
                  ),
                  child: const Text(
                    'Cancel SOS',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
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
              child: const Icon(Icons.check, color: Colors.white, size: 44),
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
              _isOfflineSos
                  ? 'Your emergency alert has been '
                        'sent to nearby devices.'
                  : 'Your emergency alert\n'
                        'is being sent...',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textGrey),
            ),

            const SizedBox(height: 28),

            const _StatusRow(
              title: 'Location Shared',
              subtitle:
                  'Your current location has been '
                  'included with the SOS',
            ),

            const SizedBox(height: 14),

            _StatusRow(
              title: _isOfflineSos
                  ? 'Offline Alert Active'
                  : 'Emergency Alert Active',
              subtitle: _isOfflineSos
                  ? 'Your SOS has been broadcast '
                        'to nearby devices'
                  : 'Your SOS request has been '
                        'recorded',
            ),

            const SizedBox(height: 14),

            _StatusRow(
              title: _isOfflineSos
                  ? 'Nearby Devices Notified'
                  : 'Help is on the way',
              subtitle: _isOfflineSos
                  ? '${_meshService.nearbyNodeCount} '
                        'nearby device(s) connected '
                        'to the mesh'
                  : 'Stay calm and wait for '
                        'assistance.',
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isCancelling ? null : _cancelSos,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  side: const BorderSide(color: AppColors.dangerRed),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isCancelling
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _isOfflineSos ? 'Cancel Offline SOS' : 'Cancel SOS',
                        style: const TextStyle(color: AppColors.dangerRed),
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

  const _StatusRow({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
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

              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
