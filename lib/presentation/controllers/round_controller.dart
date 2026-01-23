import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/import/stop_csv_parser.dart';
import '../../data/repositories/round_repository.dart';
import '../../data/services/geocode_cache.dart';
import '../../data/services/google_maps_api.dart';
import '../../domain/entities/round.dart';
import '../../domain/entities/stop.dart';
import '../../domain/usecases/route_optimizer.dart';
import '../services/location_service.dart';

class RoundController extends StateNotifier<AsyncValue<Round>> {
  RoundController({
    required this.roundId,
    required this.repo,
    required this.api,
    required this.geocodeCache,
    required this.optimizer,
    required this.locationService,
  }) : super(const AsyncLoading());

  final String roundId;
  final RoundRepository repo;
  final GoogleMapsApi api;
  final GeocodeCache geocodeCache;
  final RouteOptimizer optimizer;
  final LocationService locationService;

  Future<void> load() async {
    state = const AsyncLoading();
    try {
      final round = await repo.getRound(roundId);
      if (round == null) throw Exception('Round not found.');
      state = AsyncData(round);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Round? get _round => state.value;

  Future<void> renameRound(String title) async {
    final round = _round;
    if (round == null) return;
    final updated = round.copyWith(title: title);
    await repo.saveRound(updated);
    state = AsyncData(updated);
  }

  Future<GeocodeResult> _geocodeWithCache(String address) async {
    final cached = await geocodeCache.get(address);
    if (cached != null) {
      return GeocodeResult(
        lat: cached.lat,
        lng: cached.lng,
        formattedAddress: cached.formattedAddress,
      );
    }

    final res = await api.geocodeAddress(address);
    await geocodeCache.set(
      address: address,
      lat: res.lat,
      lng: res.lng,
      formattedAddress: res.formattedAddress,
    );
    return res;
  }

  Future<void> addStop({
    required String address,
    String? name,
    String? notes,
    String? phone,
    int? parcelCount,
  }) async {
    final round = _round;
    if (round == null) return;

    final geo = await _geocodeWithCache(address);

    final stop = Stop(
      id: const Uuid().v4(),
      address: geo.formattedAddress,
      name: name,
      notes: notes,
      phone: phone,
      parcelCount: parcelCount,
      lat: geo.lat,
      lng: geo.lng,
      orderIndex: round.stops.length,
    );

    final updated = round.copyWith(stops: [...round.stops, stop]);
    await repo.saveRound(updated);
    state = AsyncData(updated);
  }

  Future<void> deleteStop(String stopId) async {
    final round = _round;
    if (round == null) return;

    final newStops = round.stops.where((s) => s.id != stopId).toList();
    // Reindex order
    final reindexed = [
      for (var i = 0; i < newStops.length; i++)
        newStops[i].copyWith(orderIndex: i)
    ];

    final updated = round.copyWith(stops: reindexed);
    await repo.saveRound(updated);
    state = AsyncData(updated);
  }

  Future<void> setStopStatus(String stopId, StopStatus status) async {
    final round = _round;
    if (round == null) return;

    final newStops = round.stops.map((s) {
      if (s.id != stopId) return s;
      return s.copyWith(
        status: status,
        statusUpdatedAt: DateTime.now(),
      );
    }).toList();

    final updated = round.copyWith(stops: newStops);
    await repo.saveRound(updated);
    state = AsyncData(updated);
  }

  Future<void> optimizeRemainingStops() async {
    final round = _round;
    if (round == null) return;

    final origin = await locationService.getCurrentLatLng();

    // If location unavailable, fall back to depot/start in round, else first stop.
    final fallbackLat = round.startLat ?? round.stopsSorted.firstOrNull?.lat;
    final fallbackLng = round.startLng ?? round.stopsSorted.firstOrNull?.lng;

    final originLat = origin?.latitude ?? fallbackLat;
    final originLng = origin?.longitude ?? fallbackLng;

    if (originLat == null || originLng == null) return;

    final delivered = round.stops.where((s) => s.isDelivered).toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    final remaining =
        round.stops.where((s) => !s.isDelivered).toList(growable: false);

    final optimized = optimizer.optimize(
      stops: remaining,
      originLat: originLat,
      originLng: originLng,
    );

    final merged = <Stop>[];
    merged.addAll(delivered);

    // Offset order indexes after delivered stops.
    for (var i = 0; i < optimized.length; i++) {
      merged.add(optimized[i].copyWith(orderIndex: delivered.length + i));
    }

    // Also reindex delivered (keep order but make indexes 0..delivered-1)
    final fixedDelivered = [
      for (var i = 0; i < delivered.length; i++)
        delivered[i].copyWith(orderIndex: i)
    ];

    final updated = round.copyWith(
        stops: [...fixedDelivered, ...merged.sublist(delivered.length)]);
    await repo.saveRound(updated);
    state = AsyncData(updated);
  }

  Future<int> importStopsFromCsv(String csvContent) async {
    final parser = StopCsvParser();
    final drafts = parser.parse(csvContent);
    return importStopDrafts(drafts);
  }

  Future<int> importStopsFromAddressLines(String text) async {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final drafts = lines.map((a) => StopDraft(address: a)).toList();
    return importStopDrafts(drafts);
  }

  Future<int> importStopDrafts(List<StopDraft> drafts) async {
    final round = _round;
    if (round == null) return 0;

    // Sequential geocode to reduce API spikes.
    var added = 0;
    final newStops = [...round.stops];

    for (final d in drafts) {
      try {
        final geo = await _geocodeWithCache(d.address);
        final stop = Stop(
          id: const Uuid().v4(),
          address: geo.formattedAddress,
          name: d.name,
          notes: d.notes,
          phone: d.phone,
          parcelCount: d.parcelCount,
          lat: geo.lat,
          lng: geo.lng,
          orderIndex: newStops.length,
        );
        newStops.add(stop);
        added++;
      } catch (_) {
        // Skip invalid/un-geocodable rows.
      }
      // Light throttle.
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }

    final updated = round.copyWith(stops: newStops);
    await repo.saveRound(updated);
    state = AsyncData(updated);
    return added;
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
