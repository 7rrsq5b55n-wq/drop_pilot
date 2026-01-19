import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/stop.dart';
import '../providers.dart';

class StopDetailScreen extends ConsumerWidget {
  const StopDetailScreen({
    super.key,
    required this.roundId,
    required this.stopId,
  });

  final String roundId;
  final String stopId;

  Uri _navigationUri(double lat, double lng) {
    if (Platform.isIOS) {
      return Uri.parse('http://maps.apple.com/?daddr=$lat,$lng&dirflg=d');
    }
    return Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roundAsync = ref.watch(roundControllerProvider(roundId));

    return Scaffold(
      appBar: AppBar(title: const Text('Stop details')),
      body: roundAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (round) {
          final stop = round.stops.firstWhere((s) => s.id == stopId);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                Text(
                  stop.name?.isNotEmpty == true ? stop.name! : 'Stop',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(stop.address),
                const SizedBox(height: 12),
                if (stop.notes?.isNotEmpty == true) ...[
                  const Text('Notes'),
                  const SizedBox(height: 4),
                  Text(stop.notes!),
                  const SizedBox(height: 12),
                ],
                if (stop.phone?.isNotEmpty == true) ...[
                  const Text('Phone'),
                  const SizedBox(height: 4),
                  Text(stop.phone!),
                  const SizedBox(height: 12),
                ],
                if (stop.parcelCount != null) ...[
                  Text('Parcels: ${stop.parcelCount}'),
                  const SizedBox(height: 12),
                ],
                const Divider(),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    final uri = _navigationUri(stop.lat, stop.lng);
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  icon: const Icon(Icons.navigation),
                  label: const Text('Navigate'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _statusButton(
                      context,
                      ref,
                      stop,
                      StopStatus.delivered,
                      'Delivered',
                      Icons.check_circle,
                    ),
                    _statusButton(
                      context,
                      ref,
                      stop,
                      StopStatus.failed,
                      'Failed',
                      Icons.cancel,
                    ),
                    _statusButton(
                      context,
                      ref,
                      stop,
                      StopStatus.skipped,
                      'Skipped',
                      Icons.redo,
                    ),
                    _statusButton(
                      context,
                      ref,
                      stop,
                      StopStatus.pending,
                      'Pending',
                      Icons.schedule,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete stop?'),
                        content: const Text('This cannot be undone.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await ref
                          .read(roundControllerProvider(roundId).notifier)
                          .deleteStop(stopId);
                      // Refresh route
                      await ref
                          .read(routeControllerProvider(roundId).notifier)
                          .refresh(force: true);
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete stop'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statusButton(
    BuildContext context,
    WidgetRef ref,
    Stop stop,
    StopStatus status,
    String label,
    IconData icon,
  ) {
    final isCurrent = stop.status == status;

    return ElevatedButton.icon(
      onPressed: isCurrent
          ? null
          : () async {
              await ref
                  .read(roundControllerProvider(roundId).notifier)
                  .setStopStatus(stop.id, status);

              await ref
                  .read(routeControllerProvider(roundId).notifier)
                  .refresh(force: true);

              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Marked: $label')),
              );
            },
      icon: Icon(icon),
      label: Text(label),
    );
  }
}
