import 'package:hive/hive.dart';

import '../../domain/entities/round.dart';
import '../local/hive_boxes.dart';
import 'round_repository.dart';

class HiveRoundRepository implements RoundRepository {
  Box get _box => Hive.box(HiveBoxes.rounds);

  @override
  Future<void> deleteRound(String id) async {
    await _box.delete(id);
  }

  @override
  Future<Round?> getRound(String id) async {
    final raw = _box.get(id);
    if (raw is Map) return Round.fromJson(raw);
    return null;
  }

  @override
  Future<List<Round>> listRounds() async {
    final rounds = <Round>[];
    for (final key in _box.keys) {
      final raw = _box.get(key);
      if (raw is Map) {
        rounds.add(Round.fromJson(raw));
      }
    }
    rounds.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return rounds;
  }

  @override
  Future<void> saveRound(Round round) async {
    await _box.put(round.id, round.toJson());
  }
}
