class Env {
  /// Pass via:
  /// flutter run --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY
  static const String googleMapsApiKey =
      String.fromEnvironment('GOOGLE_MAPS_API_KEY', defaultValue: '');

  static bool get hasGoogleMapsApiKey => googleMapsApiKey.trim().isNotEmpty;
}
