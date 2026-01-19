class Env {
  /// Directions/Geocoding key (recommended: a Web Service restricted key).
  ///
  /// Supply at runtime:
  /// flutter run --dart-define=GOOGLE_MAPS_API_KEY=...
  static const String googleMapsApiKey =
      String.fromEnvironment('GOOGLE_MAPS_API_KEY');

  static bool get hasGoogleMapsApiKey => googleMapsApiKey.trim().isNotEmpty;
}
