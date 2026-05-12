import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firebase_paths.dart';
import '../../domain/entities/fantasy_round_settlement_marker.dart';
import '../../domain/repositories/fantasy_round_settlement_repository.dart';
import '../models/fantasy_round_settlement_marker_model.dart';

class FantasyRoundSettlementRepositoryImpl
    implements FantasyRoundSettlementRepository {
  final FirebaseFirestore _firestore;

  FantasyRoundSettlementRepositoryImpl({
    FirebaseFirestore? db,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? db ?? FirebaseFirestore.instance;

  CollectionReference get _markersRef =>
      _firestore.collection(FirebasePaths.fantasyRoundSettlements);

  @override
  Future<FantasyRoundSettlementMarker?> getSettlementMarker({
    required String leagueId,
    required int gameweek,
    required String settlementType,
  }) async {
    final docId = FantasyRoundSettlementMarker.buildId(
      leagueId: leagueId,
      gameweek: gameweek,
      settlementType: settlementType,
    );
    final doc = await _markersRef.doc(docId).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return FantasyRoundSettlementMarkerModel.fromJson(
      doc.data()! as Map<String, dynamic>,
      doc.id,
    ).toEntity();
  }

  @override
  Future<void> saveSettlementMarker(FantasyRoundSettlementMarker marker) async {
    final model = FantasyRoundSettlementMarkerModel.fromEntity(marker);
    await _markersRef.doc(marker.id).set(model.toJson());
  }
}
