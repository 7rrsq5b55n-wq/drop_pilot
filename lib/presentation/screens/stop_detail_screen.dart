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
      // Apple Maps
      return Uri.parse('http://maps.apple.com/?daddr=$lat,$lng&dirflg=d');
    }
    // Default: Google Maps
    return Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );
  }

  Future<void> _launchNavigation(BuildContext context, Stop stop) async {
    final uri = _navigationUri(stop.lat, stop.lng);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open navigation app.')),
      );
    }
  }

  Future<void> _markDeliveredAndGoNext(BuildContext context, WidgetRef ref) async {
    final confirmAction = await showDialog<_NextAction>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delivered?'),
        content: const Text(
          'Mark this stop as delivered, then move to the next stop?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _NextAction.none),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _NextAction.openNextStop),
            child: const Text('Open next stop'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, _NextAction.navigateNext),
            child: const Text('Navigate next'),
          ),
        ],
      ),
    );

    if (confirmAction == null || confirmAction == _NextAction.none) return;

    // 1) Mark delivered
    await ref
        .read(roundControllerProvider(roundId).notifier)
        .updateStopStatus(stopId, StopStatus.delivered);

    // 2) Recalculate route (so "next stop" is correct)
    await ref.read(routeControllerProvider(roundId).notifier).refresh(force: true);

    // 3) Get updated round + next stop
    final updatedRound = ref.read(roundControllerProvider(roundId)).value;
    final nextStop = updatedRound?.nextStop;

    if (!context.mounted) return;

    if (nextStop == null) {
      // No more stops
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All stops complete 🎉')),
      );
      Navigator.of(context).pop(); // back to list/map
      return;
    }

    // 4) Either open next stop screen, or launch navigation to next stop
    if (confirmAction == _NextAction.openNextStop) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => StopDetailScreen(roundId: roundId, stopId: nextStop.id),
        ),
      );
    } else {
      // navigateNext
      await _launchNavigation(context, nextStop);

      // Optional UX improvement: also open the next stop screen behind the scenes
      // so when user comes back to the app they're already on the next stop.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => StopDetailScreen(roundId: roundId, stopId: nextStop.id),
        ),
      );
    }
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
          final stop = round.stops.firstWhereOrNull((s) => s.id == stopId);

          if (stop == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'That stop is no longer available (it may have been removed or completed).',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Back'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                Text(
                  stop.name?.trim().isNotEmpty == true ? stop.name! : 'Stop',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(stop.address),
                const SizedBox(height: 12),
                if (stop.notes?.trim().isNotEmpty == true) ...[
                  const Text('Notes'),
                  const SizedBox(height: 4),
                  Text(stop.notes!),
                  const SizedBox(height: 12),
                ],
                if (stop.phone?.trim().isNotEmpty == true) ...[
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
                  onPressed: () => _launchNavigation(context, stop),
                  icon: const Icon(Icons.navigation),
                  label: const Text('Navigate'),
                ),
                const SizedBox(height: 12),

                // ✅ The key feature you asked for:
                ElevatedButton.icon(
                  onPressed: () => _markDeliveredAndGoNext(context, ref),
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Delivered → Next'),
                ),

                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    await ref
                        .read(roundControllerProvider(roundId).notifier)
                        .updateStopStatus(stopId, StopStatus.failed);

                    await ref
                        .read(routeControllerProvider(roundId).notifier)
                        .refresh(force: true);

                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Marked as failed.')),
                    );
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.cancel),
                  label: const Text('Mark failed'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

enum _NextAction { none, openNextStop, navigateNext }

extension _FirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final x in this) {
      if (test(x)) return x;
    }
    return null;
  }
}
