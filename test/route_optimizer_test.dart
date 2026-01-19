import 'package:flutter_test/flutter_test.dart';

import 'package:ecoroute_driver/domain/entities/stop.dart';
import 'package:ecoroute_driver/domain/usecases/route_optimizer.dart';

void main() {
  test('RouteOptimizer returns all stops with unique orderIndex', () {
    final optimizer = RouteOptimizer();

    final stops = [
      Stop(id: 'a', address: 'A', lat: 0.0, lng: 1.0, orderIndex: 0),
      Stop(id: 'b', address: 'B', lat: 0.0, lng: 2.0, orderIndex: 1),
      Stop(id: 'c', address: 'C', lat: 1.0, lng: 2.0, orderIndex: 2),
      Stop(id: 'd', address: 'D', lat: 1.0, lng: 1.0, orderIndex: 3),
    ];

    final optimized = optimizer.optimize(
      stops: stops,
      originLat: 0.0,
      originLng: 0.0,
      max2OptPasses: 2,
    );

    expect(optimized.length, stops.length);

    final ids = optimized.map((s) => s.id).toSet();
    expect(ids.length, stops.length);

    final orderIdx = optimized.map((s) => s.orderIndex).toSet();
    expect(orderIdx.length, stops.length);
    expect(orderIdx.contains(0), true);
    expect(orderIdx.contains(stops.length - 1), true);
  });
}
