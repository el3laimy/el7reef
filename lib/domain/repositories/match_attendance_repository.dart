import '../entities/match_attendance.dart';

abstract class MatchAttendanceRepository {
  Future<MatchAttendance?> getAttendance(String attendanceId);
  Future<void> createAttendance(MatchAttendance attendance);
  Future<void> updateAttendance(MatchAttendance attendance);
  Future<List<MatchAttendance>> getMatchAttendances(String matchId);
  Future<List<MatchAttendance>> getTeamAttendances({
    required String matchId,
    String? teamId,
    String? guestTeamId,
  });
  Future<MatchAttendance?> getAttendanceByPlayerId({
    required String matchId,
    required String playerId,
  });
  Future<MatchAttendance?> getAttendanceByGuestPlayerId({
    required String matchId,
    required String guestPlayerId,
  });
}
