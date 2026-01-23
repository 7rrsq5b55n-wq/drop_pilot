import '../../core/utils/haversine.dart';
import '../entities/stop.dart';

class RouteOptimizer {
  /// Optimize the order of `stops` starting from an origin point.
  ///
  /// This is a pragmatic offline-friendly heuristic:
  /// - Nearest Neighbor to build an initial route
  /// - 2-opt to improve it
  ///
  /// Returns a NEW list of stops with updated `orderIndex`.
  List<Stop> optimize({
    required List<Stop> stops,
    required double originLat,
    required double originLng,
    int max2OptPasses = 2,
  }) {
    if (stops.length <= 1) return stops;

    // Only optimize the provided list; caller decides whether to include delivered stops.
    final unvisited = [...stops];
    final ordered = <Stop>[];

    double currLat = originLat;
    double currLng = originLng;

    while (unvisited.isNotEmpty) {
      unvisited.sort((a, b) {
        final da = haversineDistanceMeters(
          lat1: currLat,
          lng1: currLng,
          lat2: a.lat,
          lng2: a.lng,
        );
        final db = haversineDistanceMeters(
          lat1: currLat,
          lng1: currLng,
          lat2: b.lat,
          lng2: b.lng,
        );
        return da.compareTo(db);
      });

      final next = unvisited.removeAt(0);
      ordered.add(next);

      currLat = next.lat;
      currLng = next.lng;
    }

    var improved = _twoOpt(
      ordered,
      originLat: originLat,
      originLng: originLng,
      maxPasses: max2OptPasses,
    );

    // Apply order indices
    return [
      for (var i = 0; i < improved.length; i++)
        improved[i].copyWith(orderIndex: i)
    ];
  }

  List<Stop> _twoOpt(
    List<Stop> route, {
    required double originLat,
    required double originLng,
    required int maxPasses,
  }) {
    if (route.length < 4) return route;

    var best = [...route];
    var bestDist =
        _routeDistance(best, originLat: originLat, originLng: originLng);

    for (var pass = 0; pass < maxPasses; pass++) {
      var improved = false;

      for (var i = 0; i < best.length - 2; i++) {
        for (var k = i + 1; k < best.length - 1; k++) {
          final candidate = _twoOptSwap(best, i, k);
          final candDist = _routeDistance(candidate,
              originLat: originLat, originLng: originLng);

          if (candDist + 0.5 < bestDist) {
            best = candidate;
            bestDist = candDist;
            improved = true;
          }
        }
      }

      if (!improved) break;
    }

    return best;
  }

  List<Stop> _twoOptSwap(List<Stop> route, int i, int k) {
    final start = route.sublist(0, i);
    final middle = route.sublist(i, k + 1).reversed;
    final end = route.sublist(k + 1);

    return [...start, ...middle, ...end];
  }

  double _routeDistance(
    List<Stop> route, {
    required double originLat,
    required double originLng,
  }) {
    double total = 0;
    double prevLat = originLat;
    double prevLng = originLng;

    for (final stop in route) {
      total += haversineDistanceMeters(
        lat1: prevLat,
        lng1: prevLng,
        lat2: stop.lat,
        lng2: stop.lng,
      );
      prevLat = stop.lat;
      prevLng = stop.lng;
    }

    return total;
  }
}
