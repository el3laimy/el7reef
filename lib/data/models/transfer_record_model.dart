import '../../domain/entities/transfer_record.dart';

/// نموذج بيانات (Model) خاص بسجل التبديلات لتسهيل التعامل مع الفايربيس (Firestore)
class TransferRecordModel extends TransferRecord {
  const TransferRecordModel({
    required super.id,
    required super.fantasyTeamId,
    required super.playerOutId,
    required super.playerInId,
    required super.gameweek,
    required super.cost,
    required super.timestamp,
  });

  /// تحويل من JSON قادم من Firestore
  factory TransferRecordModel.fromJson(Map<String, dynamic> json, String documentId) {
    return TransferRecordModel(
      id: documentId,
      fantasyTeamId: json['fantasyTeamId'] as String? ?? '',
      playerOutId: json['playerOutId'] as String? ?? '',
      playerInId: json['playerInId'] as String? ?? '',
      gameweek: json['gameweek'] as int? ?? 1,
      cost: json['cost'] as int? ?? 0,
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int)
          : DateTime.now(),
    );
  }

  /// تحويل إلى JSON لإرساله إلى Firestore
  Map<String, dynamic> toJson() {
    return {
      'fantasyTeamId': fantasyTeamId,
      'playerOutId': playerOutId,
      'playerInId': playerInId,
      'gameweek': gameweek,
      'cost': cost,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  /// تحويل من Entity نقية إلى Model
  factory TransferRecordModel.fromEntity(TransferRecord entity) {
    return TransferRecordModel(
      id: entity.id,
      fantasyTeamId: entity.fantasyTeamId,
      playerOutId: entity.playerOutId,
      playerInId: entity.playerInId,
      gameweek: entity.gameweek,
      cost: entity.cost,
      timestamp: entity.timestamp,
    );
  }

  /// إرجاع Entity نقية للاستخدام في طبقة Domain
  TransferRecord toEntity() {
    return TransferRecord(
      id: id,
      fantasyTeamId: fantasyTeamId,
      playerOutId: playerOutId,
      playerInId: playerInId,
      gameweek: gameweek,
      cost: cost,
      timestamp: timestamp,
    );
  }
}
