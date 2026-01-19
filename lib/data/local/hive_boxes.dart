import 'package:hive/hive.dart';

class HiveBoxes {
  static const String rounds = 'rounds';
  static const String settings = 'settings';
  static const String geocodeCache = 'geocode_cache';

  static Future<void> openAll() async {
    await Hive.openBox(rounds);
    await Hive.openBox(settings);
    await Hive.openBox(geocodeCache);
  }
}
