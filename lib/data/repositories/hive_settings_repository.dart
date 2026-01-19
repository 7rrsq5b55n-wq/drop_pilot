import 'package:hive/hive.dart';

import '../../presentation/models/app_settings.dart';
import '../local/hive_boxes.dart';
import 'settings_repository.dart';

class HiveSettingsRepository implements SettingsRepository {
  Box get _box => Hive.box(HiveBoxes.settings);

  static const _key = 'app_settings';

  @override
  Future<AppSettings> load() async {
    final raw = _box.get(_key);
    if (raw is Map) return AppSettings.fromJson(raw);
    return AppSettings.defaults();
  }

  @override
  Future<void> save(AppSettings settings) async {
    await _box.put(_key, settings.toJson());
  }
}
