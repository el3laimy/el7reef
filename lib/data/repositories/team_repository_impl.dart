import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/errors/firebase_error_handler.dart';
import '../../core/constants/firebase_paths.dart';
import '../../domain/entities/team.dart';
import '../../domain/repositories/team_repository.dart';
import '../models/team_model.dart';

/// تنفيذ مستودع الفريق مع Firestore
class TeamRepositoryImpl implements TeamRepository {
  final FirebaseFirestore _firestore;

  TeamRepositoryImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _teamsRef =>
      _firestore.collection(FirebasePaths.teams);

  @override
  Future<Team?> getTeam(String teamId) async {
    return FirebaseErrorHandler.guard(() async {
      final doc = await _teamsRef.doc(teamId).get();
      if (!doc.exists || doc.data() == null) return null;
      return TeamModel.fromJson(
        doc.data()! as Map<String, dynamic>,
        doc.id,
      ).toEntity();
    });
  }

  @override
  Future<List<Team>> getTeamsByIds(List<String> teamIds) async {
    return FirebaseErrorHandler.guard(() async {
      final orderedIds = _normalizeIds(teamIds);
      if (orderedIds.isEmpty) {
        return const <Team>[];
      }

      final loadedTeams = <String, Team>{};
      for (final chunk in _chunkIds(orderedIds)) {
        final snapshot = await _teamsRef
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in snapshot.docs) {
          final data = doc.data();
          if (data == null) {
            continue;
          }
          loadedTeams[doc.id] = TeamModel.fromJson(
            data as Map<String, dynamic>,
            doc.id,
          ).toEntity();
        }
      }

      return orderedIds
          .map((id) => loadedTeams[id])
          .whereType<Team>()
          .toList(growable: false);
    });
  }

  @override
  Future<void> createTeam(Team team) async {
    return FirebaseErrorHandler.guard(() async {
      final model = TeamModel.fromEntity(team);
      await _teamsRef.doc(team.id).set(model.toJson());
    });
  }

  @override
  Future<void> updateTeam(Team team) async {
    return FirebaseErrorHandler.guard(() async {
      final model = TeamModel.fromEntity(team);
      await _teamsRef.doc(team.id).update(model.toJson());
    });
  }

  @override
  Future<void> updateTeamLogo(String teamId, String? logoUrl) async {
    return FirebaseErrorHandler.guard(() async {
      await _teamsRef.doc(teamId).update({'logoUrl': logoUrl});
    });
  }

  @override
  Future<List<Team>> getPlayerTeams(String playerId) async {
    return FirebaseErrorHandler.guard(() async {
      final snapshot = await _teamsRef
          .where('playerIds', arrayContains: playerId)
          .get();
      return snapshot.docs
          .map(
            (doc) => TeamModel.fromJson(
              doc.data()! as Map<String, dynamic>,
              doc.id,
            ).toEntity(),
          )
          .toList();
    });
  }

  @override
  Future<void> addPlayerToTeam(String teamId, String playerId) async {
    return FirebaseErrorHandler.guard(() async {
      await _teamsRef.doc(teamId).update({
        'playerIds': FieldValue.arrayUnion([playerId]),
      });
    });
  }

  @override
  Future<void> removePlayerFromTeam(String teamId, String playerId) async {
    return FirebaseErrorHandler.guard(() async {
      await _teamsRef.doc(teamId).update({
        'playerIds': FieldValue.arrayRemove([playerId]),
      });
    });
  }

  @override
  Future<List<Team>> searchTeams(String query) async {
    return FirebaseErrorHandler.guard(() async {
      final normalizedQuery = query.trim().toLowerCase();
      if (normalizedQuery.isEmpty) {
        return const <Team>[];
      }
      final snapshot = await _teamsRef
          .where('nameLower', isGreaterThanOrEqualTo: normalizedQuery)
          .where('nameLower', isLessThanOrEqualTo: '$normalizedQuery\uf8ff')
          .limit(20)
          .get();
      return snapshot.docs
          .map(
            (doc) => TeamModel.fromJson(
              doc.data()! as Map<String, dynamic>,
              doc.id,
            ).toEntity(),
          )
          .toList();
    });
  }

  @override
  Future<void> leaveTeam(String teamId, String playerId) async {
    return FirebaseErrorHandler.guard(() async {
      final team = await getTeam(teamId);
      if (team == null) return;

      final batch = _firestore.batch();
      final teamDoc = _teamsRef.doc(teamId);

      // AUTO-01: نقل الملكية لو القائد يغادر
      if (team.ownerId == playerId) {
        if (team.playerIds.length <= 1) {
          // هو الوحيد في الفريق -> حذف الفريق
          batch.delete(teamDoc);
          await batch.commit();
          return;
        } else {
          // اختيار القائد الجديد
          String newOwnerId;
          if (team.viceCaptainIds.isNotEmpty) {
            // ترقية أول نائب
            newOwnerId = team.viceCaptainIds.first;
          } else {
            // ترقية أي شخص آخر
            newOwnerId = team.playerIds.firstWhere((id) => id != playerId);
          }

          // تحديث المستند: القائد الجديد، وتقليل قوائم القائد السابق
          batch.update(teamDoc, {
            'ownerId': newOwnerId,
            'viceCaptainIds': FieldValue.arrayRemove([newOwnerId, playerId]),
            'playerIds': FieldValue.arrayRemove([playerId]),
          });
        }
      } else {
        // لاعب عادي يغادر
        batch.update(teamDoc, {
          'playerIds': FieldValue.arrayRemove([playerId]),
          'viceCaptainIds': FieldValue.arrayRemove([playerId]),
        });
      }

      await batch.commit();
    });
  }

  @override
  Future<void> transferOwnership(
    String teamId,
    String currentOwnerId,
    String newOwnerId,
  ) async {
    return FirebaseErrorHandler.guard(() async {
      await _teamsRef.doc(teamId).update({
        'ownerId': newOwnerId,
        'viceCaptainIds': FieldValue.arrayRemove([
          newOwnerId,
        ]), // لا يمكن أن يكون نائب ومالك في نفس الوقت
      });
    });
  }

  @override
  Future<void> promoteToViceCaptain(
    String teamId,
    String ownerId,
    String targetId,
  ) async {
    return FirebaseErrorHandler.guard(() async {
      // التأكد من أن الذي يقوم بالترقية هو المالك الفعلي يتم في الواجهة أو في الـ Security Rules يفضل
      await _teamsRef.doc(teamId).update({
        'viceCaptainIds': FieldValue.arrayUnion([targetId]),
      });
    });
  }

  @override
  Future<void> kickPlayer(
    String teamId,
    String actionUserId,
    String targetId,
  ) async {
    return FirebaseErrorHandler.guard(() async {
      // يمكن التحقق من أن الـ actionUserId هو owner او viceCaptain
      await _teamsRef.doc(teamId).update({
        'playerIds': FieldValue.arrayRemove([targetId]),
        'viceCaptainIds': FieldValue.arrayRemove([targetId]),
      });
    });
  }

  List<String> _normalizeIds(List<String> ids) {
    return ids
        .where((id) => id.trim().isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  Iterable<List<String>> _chunkIds(List<String> ids, {int size = 10}) sync* {
    for (var index = 0; index < ids.length; index += size) {
      final end = (index + size) > ids.length ? ids.length : index + size;
      yield ids.sublist(index, end);
    }
  }
}
