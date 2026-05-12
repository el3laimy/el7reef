import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/errors/firebase_error_handler.dart';
import '../../core/constants/firebase_paths.dart';
import '../../domain/entities/match_attendance.dart';
import '../../domain/repositories/match_attendance_repository.dart';
import '../models/match_attendance_model.dart';

class MatchAttendanceRepositoryImpl implements MatchAttendanceRepository {
  final FirebaseFirestore _firestore;

  MatchAttendanceRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _attendanceRef =>
      _firestore.collection(FirebasePaths.matchAttendances);

  @override
  Future<MatchAttendance?> getAttendance(String attendanceId) async {
    return FirebaseErrorHandler.guard(() async {
      final doc = await _attendanceRef.doc(attendanceId).get();
      if (!doc.exists || doc.data() == null) {
        return null;
      }
      return MatchAttendanceModel.fromJson(doc.data()!, doc.id).toEntity();
    });
  }

  @override
  Future<void> createAttendance(MatchAttendance attendance) async {
    return FirebaseErrorHandler.guard(() async {
      final model = MatchAttendanceModel.fromEntity(attendance);
      await _attendanceRef.doc(attendance.id).set(model.toJson());
    });
  }

  @override
  Future<void> updateAttendance(MatchAttendance attendance) async {
    return FirebaseErrorHandler.guard(() async {
      final model = MatchAttendanceModel.fromEntity(attendance);
      await _attendanceRef.doc(attendance.id).update(model.toJson());
    });
  }

  @override
  Future<List<MatchAttendance>> getMatchAttendances(String matchId) async {
    return FirebaseErrorHandler.guard(() async {
      final snapshot = await _attendanceRef.where('matchId', isEqualTo: matchId).get();
      final attendances = snapshot.docs
          .map((doc) => MatchAttendanceModel.fromJson(doc.data(), doc.id).toEntity())
          .toList(growable: true);
      attendances.sort((left, right) => left.createdAt.compareTo(right.createdAt));
      return attendances;
    });
  }

  @override
  Future<List<MatchAttendance>> getTeamAttendances({
    required String matchId,
    String? teamId,
    String? guestTeamId,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      if ((teamId != null) == (guestTeamId != null)) {
        throw ArgumentError(
          'Exactly one of teamId or guestTeamId must be provided.',
        );
      }

      Query<Map<String, dynamic>> query =
          _attendanceRef.where('matchId', isEqualTo: matchId);
      if (teamId != null) {
        query = query.where('teamId', isEqualTo: teamId);
      } else {
        query = query.where('guestTeamId', isEqualTo: guestTeamId);
      }

      final snapshot = await query.get();
      final attendances = snapshot.docs
          .map((doc) => MatchAttendanceModel.fromJson(doc.data(), doc.id).toEntity())
          .toList(growable: true);
      attendances.sort((left, right) => left.createdAt.compareTo(right.createdAt));
      return attendances;
    });
  }

  @override
  Future<MatchAttendance?> getAttendanceByPlayerId({
    required String matchId,
    required String playerId,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      final snapshot = await _attendanceRef
          .where('matchId', isEqualTo: matchId)
          .where('playerId', isEqualTo: playerId)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) {
        return null;
      }
      final doc = snapshot.docs.first;
      return MatchAttendanceModel.fromJson(doc.data(), doc.id).toEntity();
    });
  }

  @override
  Future<MatchAttendance?> getAttendanceByGuestPlayerId({
    required String matchId,
    required String guestPlayerId,
  }) async {
    return FirebaseErrorHandler.guard(() async {
      final snapshot = await _attendanceRef
          .where('matchId', isEqualTo: matchId)
          .where('guestPlayerId', isEqualTo: guestPlayerId)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) {
        return null;
      }
      final doc = snapshot.docs.first;
      return MatchAttendanceModel.fromJson(doc.data(), doc.id).toEntity();
    });
  }
}
