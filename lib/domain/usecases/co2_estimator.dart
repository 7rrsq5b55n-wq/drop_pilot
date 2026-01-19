enum VehicleType { ev, hybrid, petrol, diesel }

class Co2Estimator {
  /// Default kg CO2 per km factors (very rough estimates).
  ///
  /// - Petrol: ~0.192 kg/km (192 g/km)
  /// - Diesel: ~0.171 kg/km (171 g/km)
  /// - Hybrid: ~0.120 kg/km (120 g/km)
  /// - EV: depends heavily on grid; default here is a low placeholder.
  static const defaultKgPerKm = <VehicleType, double>{
    VehicleType.ev: 0.05,
    VehicleType.hybrid: 0.12,
    VehicleType.petrol: 0.192,
    VehicleType.diesel: 0.171,
  };

  double estimateKg({
    required int distanceMeters,
    required VehicleType vehicleType,
    Map<VehicleType, double>? overridesKgPerKm,
  }) {
    final km = distanceMeters / 1000.0;
    final factor = (overridesKgPerKm ?? defaultKgPerKm)[vehicleType] ??
        defaultKgPerKm[VehicleType.petrol]!;
    return km * factor;
  }
}
