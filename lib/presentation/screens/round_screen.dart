import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/env.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/stop.dart';
import '../controllers/route_controller.dart';
import '../providers.dart';
import 'add_stop_screen.dart';
import 'settings_screen.dart';
import 'stop_detail_screen.dart';

class RoundScreen extends ConsumerStatefulWidget {
  const RoundScreen({super.key, required this.roundId});

  final String roundId;

  @override
  ConsumerState<RoundScreen> createState() => _RoundScreenState();
}

class _RoundScreenState extends ConsumerState<RoundScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _tab.dispose();
    super.dispose();
  }

  Future<void> _importCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.first.bytes;
    if (bytes == null) return;
    final csvContent = String.fromCharCodes(bytes);

    final added = await ref
        .read(roundControllerProvider(widget.roundId).notifier)
        .importStopsFromCsv(csvContent);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Imported $added stops.')),
    );
  }

  Future<void> _pasteAddresses() async {
    final controller = TextEditingController();

    final text = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Paste addresses'),
        content: TextField(
          controller: controller,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: 'One address per line',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (text == null || text.trim().isEmpty) return;

    final added = await ref
        .read(roundControllerProvider(widget.roundId).notifier)
        .importStopsFromAddressLines(text);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Imported $added stops.')),
    );
  }

  Future<void> _navigateToStop(Stop stop) async {
    // Guard against bad coordinates (a common cause of routing errors).
    final lat = stop.lat;
    final lng = stop.lng;

    final coordsValid = lat.isFinite &&
        lng.isFinite &&
        lat.abs() <= 90 &&
        lng.abs() <= 180 &&
        !(lat == 0 && lng == 0);

    if (!coordsValid) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'This stop has invalid coordinates. Please re-geocode: ${stop.address}',
          ),
        ),
      );
      return;
    }

    final uri = _navigationUri(lat, lng);

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open navigation app.')),
      );
    }
  }

  Uri _navigationUri(double lat, double lng) {
    if (Platform.isIOS) {
      // Apple Maps (uses current location by default as origin)
      return Uri.parse('http://maps.apple.com/?daddr=$lat,$lng&dirflg=d');
    }
    // Google Maps URL (uses current location by default as origin)
    return Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );
  }

  @override
  Widget build(BuildContext context) {
    final roundAsync = ref.watch(roundControllerProvider(widget.roundId));
    final routeState = ref.watch(routeControllerProvider(widget.roundId));

    return Scaffold(
      appBar: AppBar(
        title: roundAsync.when(
          loading: () => const Text('Round'),
          error: (e, _) => Text('Error: $e'),
          data: (r) => Text(r.title),
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.settings),
          ),
          IconButton(
            tooltip: 'Refresh route',
            onPressed: () => ref
                .read(routeControllerProvider(widget.roundId).notifier)
                .refresh(force: true),
            icon: const Icon(Icons.route),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(icon: Icon(Icons.list), text: 'Stops'),
            Tab(icon: Icon(Icons.map), text: 'Map'),
          ],
        ),
      ),
      body: roundAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Error: $e'),
          ),
        ),
        data: (round) {
          return TabBarView(
            controller: _tab,
            children: [
              _StopsTab(
                roundId: widget.roundId,
                onImportCsv: _importCsv,
                onPasteAddresses: _pasteAddresses,
                onOpenStop: (stop) async {
                  final result = await Navigator.of(context).push<String?>(
                    MaterialPageRoute(
                      builder: (_) => StopDetailScreen(
                        roundId: widget.roundId,
                        stopId: stop.id,
                      ),
                    ),
                  );

                  if (!context.mounted) return;

                  // StopDetailScreen should return this token after status update
                  if (result == 'NAVIGATE_NEXT') {
                    final next = round.nextStop;
                    if (next == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Round complete ✅')),
                      );
                      return;
                    }

                    // Keep the order fresh (optional but matches your “end-to-end” intent)
                    await ref
                        .read(roundControllerProvider(widget.roundId).notifier)
                        .optimizeRemainingStops();

                    // Refresh polylines/ETA
                    await ref
                        .read(routeControllerProvider(widget.roundId).notifier)
                        .refresh(force: true);

                    await _navigateToStop(next);
                  }
                },
                onNavigate: _navigateToStop,
              ),
              _MapTab(
                roundId: widget.roundId,
                mapController: _mapController,
                onMapCreated: (c) => _mapController = c,
                routeState: routeState,
                onNavigateNext: () async {
                  final next = round.nextStop;
                  if (next == null) return;

                  await ref
                      .read(roundControllerProvider(widget.roundId).notifier)
                      .optimizeRemainingStops();

                  await ref
                      .read(routeControllerProvider(widget.roundId).notifier)
                      .refresh(force: true);

                  await _navigateToStop(next);
                },
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add stop',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AddStopScreen(roundId: widget.roundId),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: (!Env.hasGoogleMapsApiKey)
          ? MaterialBanner(
              content: const Text(
                'Missing GOOGLE_MAPS_API_KEY dart-define. Geocoding/Directions will not work.',
              ),
              actions: [
                TextButton(
                  onPressed: () {},
                  child: const Text('OK'),
                ),
              ],
            )
          : null,
    );
  }
}

class _StopsTab extends ConsumerWidget {
  const _StopsTab({
    required this.roundId,
    required this.onImportCsv,
    required this.onPasteAddresses,
    required this.onOpenStop,
    required this.onNavigate,
  });

  final String roundId;
  final VoidCallback onImportCsv;
  final VoidCallback onPasteAddresses;

  // Use Future callbacks so we can await internally when needed.
  final Future<void> Function(Stop stop) onOpenStop;
  final Future<void> Function(Stop stop) onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roundAsync = ref.watch(roundControllerProvider(roundId));

    return roundAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (round) {
        final stops = round.stopsSorted;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: onImportCsv,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Import CSV'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onPasteAddresses,
                    icon: const Icon(Icons.paste),
                    label: const Text('Paste list'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await ref
                          .read(roundControllerProvider(roundId).notifier)
                          .optimizeRemainingStops();

                      await ref
                          .read(routeControllerProvider(roundId).notifier)
                          .refresh(force: true);
                    },
                    icon: const Icon(Icons.auto_fix_high),
                    label: const Text('Optimize'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: stops.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No stops yet. Tap + to add one.'),
                      ),
                    )
                  : ListView.separated(
                      itemCount: stops.length,
                      separatorBuilder: (context, _) =>
                          const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final s = stops[i];
                        return ListTile(
                          leading: _StatusDot(status: s.status),
                          title: Text(
                            s.name?.trim().isNotEmpty == true
                                ? s.name!
                                : s.address,
                          ),
                          subtitle: Text(s.address),
                          trailing: IconButton(
                            tooltip: 'Navigate',
                            icon: const Icon(Icons.navigation),
                            onPressed: () {
                              onNavigate(s); // ignore returned Future
                            },
                          ),
                          onTap: () {
                            onOpenStop(s); // ignore returned Future
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final StopStatus status;

  @override
  Widget build(BuildContext context) {
    Color c;
    switch (status) {
      case StopStatus.delivered:
        c = Colors.green;
        break;
      case StopStatus.failed:
        c = Colors.red;
        break;
      case StopStatus.skipped:
        c = Colors.orange;
        break;
      case StopStatus.pending:
        c = Colors.grey;
        break;
    }
    return CircleAvatar(radius: 8, backgroundColor: c);
  }
}

class _MapTab extends ConsumerWidget {
  const _MapTab({
    required this.roundId,
    required this.mapController,
    required this.onMapCreated,
    required this.routeState,
    required this.onNavigateNext,
  });

  final String roundId;
  final GoogleMapController? mapController;
  final void Function(GoogleMapController controller) onMapCreated;
  final RouteState routeState;

  // We accept async callback and ignore its Future in onPressed.
  final Future<void> Function() onNavigateNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roundAsync = ref.watch(roundControllerProvider(roundId));
    final settings = ref.watch(settingsControllerProvider).value;

    return roundAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (round) {
        final stops = round.stopsSorted;

        final markers = <Marker>{};
        for (final s in stops) {
          final hue = switch (s.status) {
            StopStatus.pending => BitmapDescriptor.hueAzure,
            StopStatus.delivered => BitmapDescriptor.hueGreen,
            StopStatus.failed => BitmapDescriptor.hueRed,
            StopStatus.skipped => BitmapDescriptor.hueOrange,
          };

          markers.add(
            Marker(
              markerId: MarkerId(s.id),
              position: LatLng(s.lat, s.lng),
              infoWindow: InfoWindow(
                title: s.name?.isNotEmpty == true ? s.name : 'Stop',
                snippet: s.address,
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(hue),
            ),
          );
        }

        final polylines = <Polyline>{
          if (routeState.polyline.isNotEmpty)
            Polyline(
              polylineId: const PolylineId('route'),
              points: routeState.polyline,
              width: 6,
            ),
        };

        LatLng initial = const LatLng(51.509865, -0.118092); // default London
        if (stops.isNotEmpty) {
          initial = LatLng(stops.first.lat, stops.first.lng);
        }

        return Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(target: initial, zoom: 11),
              markers: markers,
              polylines: polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              onMapCreated: onMapCreated,
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Route summary',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          if (routeState.loading)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Distance: ${formatDistance(routeState.totalDistanceMeters)}',
                      ),
                      Text(
                        'ETA: ${formatDuration(routeState.totalDurationSeconds)}'
                        '${routeState.totalDurationInTrafficSeconds != null ? ' (traffic: ${formatDuration(routeState.totalDurationInTrafficSeconds!)})' : ''}',
                      ),
                      if (routeState.co2Kg != null)
                        Text(
                          'Estimated CO₂: ${routeState.co2Kg!.toStringAsFixed(2)} kg (estimate)',
                        ),
                      if (settings != null)
                        Text(
                          'Mode: ${settings.ecoMode ? 'Eco' : 'Standard'}'
                          ' | Avoid tolls: ${settings.avoidTolls ? 'On' : 'Off'}'
                          ' | Avoid highways: ${settings.avoidHighways ? 'On' : 'Off'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      if (routeState.error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Route error: ${routeState.error}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              onNavigateNext(); // ignore returned Future
                            },
                            icon: const Icon(Icons.navigation),
                            label: const Text('Navigate next'),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: () => ref
                                .read(routeControllerProvider(roundId).notifier)
                                .refresh(force: true),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Recalculate'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
