import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../data/repositories/hive_round_repository.dart';
import '../data/repositories/round_repository.dart';
import '../data/repositories/hive_settings_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/services/geocode_cache.dart';
import '../data/services/google_maps_api.dart';
import '../domain/usecases/route_optimizer.dart';
import '../domain/usecases/co2_estimator.dart';
import '../domain/entities/round.dart';
import 'controllers/rounds_controller.dart';
import 'controllers/round_controller.dart';
import 'controllers/settings_controller.dart';
import 'controllers/route_controller.dart';
import 'models/app_settings.dart';
import 'services/location_service.dart';

final httpClientProvider = Provider<http.Client>((ref) => http.Client());

final roundRepositoryProvider = Provider<RoundRepository>((ref) {
  return HiveRoundRepository();
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return HiveSettingsRepository();
});

final geocodeCacheProvider = Provider<GeocodeCache>((ref) {
  return GeocodeCache();
});

final googleMapsApiProvider = Provider<GoogleMapsApi>((ref) {
  final client = ref.watch(httpClientProvider);
  return GoogleMapsApi(client);
});

final routeOptimizerProvider = Provider<RouteOptimizer>((ref) {
  return RouteOptimizer();
});

final co2EstimatorProvider = Provider<Co2Estimator>((ref) {
  return Co2Estimator();
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, AsyncValue<AppSettings>>((ref) {
  return SettingsController(
    repo: ref.watch(settingsRepositoryProvider),
  )..load();
});

final roundsControllerProvider =
    StateNotifierProvider<RoundsController, AsyncValue<List<Round>>>((ref) {
  return RoundsController(
    repo: ref.watch(roundRepositoryProvider),
  )..load();
});

final roundControllerProvider =
    StateNotifierProvider.family<RoundController, AsyncValue<Round>, String>(
        (ref, id) {
  return RoundController(
    roundId: id,
    repo: ref.watch(roundRepositoryProvider),
    api: ref.watch(googleMapsApiProvider),
    geocodeCache: ref.watch(geocodeCacheProvider),
    optimizer: ref.watch(routeOptimizerProvider),
    locationService: ref.watch(locationServiceProvider),
  )..load();
});

final routeControllerProvider = StateNotifierProvider.autoDispose
    .family<RouteController, RouteState, String>((ref, roundId) {
  return RouteController(
    ref: ref,
    roundId: roundId,
    api: ref.watch(googleMapsApiProvider),
    co2: ref.watch(co2EstimatorProvider),
    locationService: ref.watch(locationServiceProvider),
  );
});
