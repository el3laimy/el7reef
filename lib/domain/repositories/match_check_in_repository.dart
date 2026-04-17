import '../entities/match_check_in.dart';

abstract class MatchCheckInRepository {
  Future<MatchCheckIn?> getCheckIn(String checkInId);
  Future<void> createCheckIn(MatchCheckIn checkIn);
  Future<void> updateCheckIn(MatchCheckIn checkIn);
  Future<List<MatchCheckIn>> getMatchCheckIns(String matchId);
  Future<MatchCheckIn?> getCheckInByTeamId({
    required String matchId,
    required String teamId,
  });
  Future<MatchCheckIn?> getCheckInByGuestTeamId({
    required String matchId,
    required String guestTeamId,
  });
}
