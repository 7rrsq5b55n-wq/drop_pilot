import 'package:intl/intl.dart';

String formatDistance(int meters) {
  if (meters < 1000) return '$meters m';
  final km = meters / 1000.0;
  return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
}

String formatDuration(int seconds) {
  final d = Duration(seconds: seconds);
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);

  if (hours <= 0) return '${d.inMinutes} min';
  return '${hours}h ${minutes}m';
}

String formatTimestamp(DateTime dt) {
  return DateFormat('yyyy-MM-dd HH:mm').format(dt);
}
