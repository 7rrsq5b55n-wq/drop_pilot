import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/repositories/round_repository.dart';
import '../../domain/entities/round.dart';

class RoundsController extends StateNotifier<AsyncValue<List<Round>>> {
  RoundsController({required this.repo}) : super(const AsyncLoading());

  final RoundRepository repo;

  Future<void> load() async {
    state = const AsyncLoading();
    try {
      final rounds = await repo.listRounds();
      state = AsyncData(rounds);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<Round> createRound({required String title}) async {
    final round = Round(id: const Uuid().v4(), title: title, stops: []);
    await repo.saveRound(round);
    await load();
    return round;
  }

  Future<void> deleteRound(String id) async {
    await repo.deleteRound(id);
    await load();
  }
}
