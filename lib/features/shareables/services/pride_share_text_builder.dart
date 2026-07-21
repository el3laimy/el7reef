import '../../../core/services/pride_share_attribution.dart';
import '../../../domain/entities/share_payload.dart';

class PrideShareTextBuilder {
  const PrideShareTextBuilder();

  String? build({
    required String? baseText,
    required SharePayload? payload,
    required bool includeGrowthLink,
  }) {
    final normalizedText = baseText?.trim();
    if (!includeGrowthLink || payload == null) {
      return normalizedText?.isEmpty ?? true ? null : normalizedText;
    }

    final link = PrideShareAttribution.attributedPublicUri(payload);
    return [
      if (normalizedText?.isNotEmpty ?? false) normalizedText!,
      link.toString(),
    ].join('\n');
  }
}
