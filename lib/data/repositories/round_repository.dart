import '../../domain/entities/round.dart';

abstract class RoundRepository {
  Future<List<Round>> listRounds();
  Future<Round?> getRound(String id);
  Future<void> saveRound(Round round);
  Future<void> deleteRound(String id);
}
