import '../../domain/usecases/co2_estimator.dart';

class AppSettings {
  AppSettings({
    required this.avoidTolls,
    required this.avoidHighways,
    required this.ecoMode,
    required this.vehicleType,
    required this.co2KgPerKmOverrides,
  });

  final bool avoidTolls;
  final bool avoidHighways;
  final bool ecoMode;
  final VehicleType vehicleType;

  /// Optional overrides for the CO2 kg/km factors.
  /// Stored as map of vehicleType.name -> double.
  final Map<String, double> co2KgPerKmOverrides;

  static AppSettings defaults() => AppSettings(
        avoidTolls: false,
        avoidHighways: false,
        ecoMode: false,
        vehicleType: VehicleType.petrol,
        co2KgPerKmOverrides: const {},
      );

  AppSettings copyWith({
    bool? avoidTolls,
    bool? avoidHighways,
    bool? ecoMode,
    VehicleType? vehicleType,
    Map<String, double>? co2KgPerKmOverrides,
  }) {
    return AppSettings(
      avoidTolls: avoidTolls ?? this.avoidTolls,
      avoidHighways: avoidHighways ?? this.avoidHighways,
      ecoMode: ecoMode ?? this.ecoMode,
      vehicleType: vehicleType ?? this.vehicleType,
      co2KgPerKmOverrides: co2KgPerKmOverrides ?? this.co2KgPerKmOverrides,
    );
  }

  Map<String, dynamic> toJson() => {
        'avoidTolls': avoidTolls,
        'avoidHighways': avoidHighways,
        'ecoMode': ecoMode,
        'vehicleType': vehicleType.name,
        'co2KgPerKmOverrides': co2KgPerKmOverrides,
      };

  static AppSettings fromJson(Map<dynamic, dynamic> json) {
    final vtStr = (json['vehicleType'] as String?) ?? VehicleType.petrol.name;
    final vt = VehicleType.values.firstWhere(
      (e) => e.name == vtStr,
      orElse: () => VehicleType.petrol,
    );

    final overridesRaw = json['co2KgPerKmOverrides'];
    final overrides = <String, double>{};
    if (overridesRaw is Map) {
      overridesRaw.forEach((k, v) {
        final key = k.toString();
        if (v is num) overrides[key] = v.toDouble();
      });
    }

    return AppSettings(
      avoidTolls: (json['avoidTolls'] as bool?) ?? false,
      avoidHighways: (json['avoidHighways'] as bool?) ?? false,
      ecoMode: (json['ecoMode'] as bool?) ?? false,
      vehicleType: vt,
      co2KgPerKmOverrides: overrides,
    );
  }
}
