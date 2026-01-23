import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../data/services/google_maps_api.dart';
import '../../domain/entities/round.dart';
import '../../domain/usecases/co2_estimator.dart';
import '../models/app_settings.dart';
import '../providers.dart';
import '../services/location_service.dart';

class RouteState {
  const RouteState({
    this.loading = false,
    this.error,
    this.polyline = const [],
    this.totalDistanceMeters = 0,
    this.totalDurationSeconds = 0,
    this.totalDurationInTrafficSeconds,
    this.lastUpdatedAt,
    this.co2Kg,
    this.origin,
  });

  final bool loading;
  final String? error;

  final List<LatLng> polyline;

  final int totalDistanceMeters;
  final int totalDurationSeconds;
  final int? totalDurationInTrafficSeconds;
  final DateTime? lastUpdatedAt;

  final double? co2Kg;
  final LatLng? origin;

  RouteState copyWith({
    bool? loading,
    String? error,
    List<LatLng>? polyline,
    int? totalDistanceMeters,
    int? totalDurationSeconds,
    int? totalDurationInTrafficSeconds,
    DateTime? lastUpdatedAt,
    double? co2Kg,
    LatLng? origin,
  }) {
    return RouteState(
      loading: loading ?? this.loading,
      error: error,
      polyline: polyline ?? this.polyline,
      totalDistanceMeters: totalDistanceMeters ?? this.totalDistanceMeters,
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      totalDurationInTrafficSeconds:
          totalDurationInTrafficSeconds ?? this.totalDurationInTrafficSeconds,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      co2Kg: co2Kg ?? this.co2Kg,
      origin: origin ?? this.origin,
    );
  }
}

class RouteController extends StateNotifier<RouteState> {
  RouteController({
    required this.ref,
    required this.roundId,
    required this.api,
    required this.co2,
    required this.locationService,
  }) : super(const RouteState()) {
    // Refresh when the round changes.
    ref.listen<AsyncValue<Round>>(roundControllerProvider(roundId),
        (prev, next) {
      if (next.hasValue) {
        refresh();
      }
    });

    // Refresh when settings change.
    ref.listen<AsyncValue<AppSettings>>(settingsControllerProvider,
        (prev, next) {
      if (next.hasValue) {
        refresh();
      }
    });

    // initial load
    refresh();
    _startAutoRefresh();
  }

  final Ref ref;
  final String roundId;
  final GoogleMapsApi api;
  final Co2Estimator co2;
  final LocationService locationService;

  Timer? _timer;
  DateTime? _lastRefresh;

  AppSettings get _settings =>
      ref.read(settingsControllerProvider).value ?? AppSettings.defaults();

  Round? get _round => ref.read(roundControllerProvider(roundId)).value;

  Future<void> refresh({bool force = false}) async {
    final now = DateTime.now();
    if (!force && _lastRefresh != null) {
      if (now.difference(_lastRefresh!) < const Duration(seconds: 20)) {
        return; // throttle
      }
    }
    _lastRefresh = now;

    final round = _round;
    if (round == null) return;

    final remaining = round.remainingStopsSorted;
    if (remaining.isEmpty) {
      state = state.copyWith(
        loading: false,
        error: null,
        polyline: const [],
        totalDistanceMeters: 0,
        totalDurationSeconds: 0,
        totalDurationInTrafficSeconds: null,
        lastUpdatedAt: DateTime.now(),
        co2Kg: 0,
      );
      return;
    }

    state = state.copyWith(loading: true, error: null);

    try {
      final origin = await locationService.getCurrentLatLng() ??
          (round.startLat != null && round.startLng != null
              ? LatLng(round.startLat!, round.startLng!)
              : LatLng(remaining.first.lat, remaining.first.lng));

      // In ecoMode we can bias by avoiding highways by default (but still user can toggle separately).
      final settings = _settings.ecoMode
          ? _settings.copyWith(avoidHighways: true)
          : _settings;

      final stopsLatLng =
          remaining.map((s) => LatLng(s.lat, s.lng)).toList(growable: false);

      final route = await api.buildMultiStopRoute(
        origin: origin,
        stopsInOrder: stopsLatLng,
        settings: settings,
      );

      final overrides = <VehicleType, double>{};
      for (final entry in settings.co2KgPerKmOverrides.entries) {
        final vt = VehicleType.values
            .where((e) => e.name == entry.key)
            .cast<VehicleType?>()
            .firstOrNull;
        if (vt != null) overrides[vt] = entry.value;
      }

      final co2Kg = co2.estimateKg(
        distanceMeters: route.totalDistanceMeters,
        vehicleType: settings.vehicleType,
        overridesKgPerKm: overrides.isEmpty ? null : overrides,
      );

      state = state.copyWith(
        loading: false,
        error: null,
        polyline: route.polylinePoints,
        totalDistanceMeters: route.totalDistanceMeters,
        totalDurationSeconds: route.totalDurationSeconds,
        totalDurationInTrafficSeconds: route.totalDurationInTrafficSeconds,
        lastUpdatedAt: DateTime.now(),
        co2Kg: co2Kg,
        origin: origin,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: e.toString(),
        lastUpdatedAt: DateTime.now(),
      );
    }
  }

  void _startAutoRefresh() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 3), (_) {
      refresh();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
