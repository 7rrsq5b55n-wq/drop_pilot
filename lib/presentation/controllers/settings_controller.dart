import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/settings_repository.dart';
import '../models/app_settings.dart';
import '../../domain/usecases/co2_estimator.dart';

class SettingsController extends StateNotifier<AsyncValue<AppSettings>> {
  SettingsController({required this.repo}) : super(const AsyncLoading());

  final SettingsRepository repo;

  Future<void> load() async {
    state = const AsyncLoading();
    try {
      final settings = await repo.load();
      state = AsyncData(settings);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  AppSettings get current => state.value ?? AppSettings.defaults();

  Future<void> update(AppSettings newSettings) async {
    state = AsyncData(newSettings);
    await repo.save(newSettings);
  }

  Future<void> setAvoidTolls(bool v) => update(current.copyWith(avoidTolls: v));
  Future<void> setAvoidHighways(bool v) =>
      update(current.copyWith(avoidHighways: v));
  Future<void> setEcoMode(bool v) => update(current.copyWith(ecoMode: v));
  Future<void> setVehicleType(VehicleType vt) =>
      update(current.copyWith(vehicleType: vt));

  Future<void> setCo2Override(VehicleType vt, double kgPerKm) async {
    final map = {...current.co2KgPerKmOverrides};
    map[vt.name] = kgPerKm;
    await update(current.copyWith(co2KgPerKmOverrides: map));
  }
}
