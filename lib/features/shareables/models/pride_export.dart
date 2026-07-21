import 'package:flutter/foundation.dart';

import '../../../domain/entities/share_payload.dart';
import 'pride_card_format.dart';

enum PrideMediaType { image, video }

const Set<ShareCardType> prideVideoSupportedCardTypes = {
  ShareCardType.matchResult,
  ShareCardType.mvp,
  ShareCardType.goalScorer,
  ShareCardType.qualification,
  ShareCardType.champion,
  ShareCardType.playerMilestone,
};

extension PrideVideoSupport on ShareCardType {
  bool get supportsVideoExport => prideVideoSupportedCardTypes.contains(this);
}

@immutable
class PrideShareSelection {
  final PrideCardFormat format;
  final PrideMediaType mediaType;
  final bool includeAudio;

  const PrideShareSelection({
    required this.format,
    required this.mediaType,
    required this.includeAudio,
  });
}

@immutable
class PrideExportRequest {
  final ShareCardType cardType;
  final PrideCardFormat format;
  final PrideMediaType mediaType;
  final String fileName;
  final bool includeAudio;

  const PrideExportRequest({
    required this.cardType,
    required this.format,
    required this.mediaType,
    required this.fileName,
    this.includeAudio = true,
  });
}

@immutable
class PrideExportResult {
  final PrideExportRequest request;
  final String? filePath;
  final Duration exportDuration;
  final bool fallbackUsed;
  final String? failureCode;

  const PrideExportResult({
    required this.request,
    required this.filePath,
    required this.exportDuration,
    this.fallbackUsed = false,
    this.failureCode,
  });

  bool get succeeded => filePath != null && failureCode == null;
}

@immutable
class PrideShareOutcome {
  final PrideExportResult exportResult;
  final PrideMediaType? sharedMediaType;

  const PrideShareOutcome({
    required this.exportResult,
    required this.sharedMediaType,
  });

  bool get usedImageFallback =>
      !cancelled &&
      exportResult.request.mediaType == PrideMediaType.video &&
      sharedMediaType == PrideMediaType.image;

  bool get usedTextFallback => !cancelled && sharedMediaType == null;

  bool get cancelled => exportResult.failureCode == 'export_cancelled';
}
