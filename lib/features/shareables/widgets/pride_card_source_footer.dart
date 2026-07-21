import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/services/pride_share_attribution.dart';
import '../../../core/widgets/el7reef_brand_mark.dart';
import '../../../domain/entities/share_payload.dart';

/// A compact, solid source boundary shared by Pride export families.
///
/// The QR contains only the public target and safe attribution parameters from
/// [SharePayload]. When growth links are disabled the verified brand mark is
/// rendered instead, so exported media never contains a dead QR.
class PrideCardSourceFooter extends StatelessWidget {
  final SharePayload payload;
  final Color accent;
  final bool includeGrowthLink;
  final bool compact;
  final bool dense;
  final String linkedLabel;
  final String verifiedLabel;
  final String qrSemanticsLabel;

  const PrideCardSourceFooter({
    super.key,
    required this.payload,
    required this.accent,
    this.includeGrowthLink = false,
    this.compact = false,
    this.dense = false,
    this.linkedLabel = 'امسح لفتح التفاصيل الموثقة على الحريف',
    this.verifiedLabel = 'بطاقة موثقة من بيانات الحريف الحقيقية',
    this.qrSemanticsLabel = 'رمز QR لفتح التفاصيل',
  });

  @override
  Widget build(BuildContext context) {
    final markSize = dense ? 32.0 : (compact ? 42.0 : 52.0);
    return Row(
      children: [
        if (includeGrowthLink)
          _AttributedQr(
            payload: payload,
            size: markSize,
            semanticsLabel: qrSemanticsLabel,
          )
        else
          El7reefBrandMark(size: markSize),
        SizedBox(width: dense ? 5 : 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'المصدر: الحريف',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: accent,
                  fontSize: dense ? 6.5 : (compact ? 9 : 10),
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                includeGrowthLink ? linkedLabel : verifiedLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textSecondaryTinted,
                  fontSize: dense ? 6 : (compact ? 8 : 9),
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AttributedQr extends StatelessWidget {
  final SharePayload payload;
  final double size;
  final String semanticsLabel;

  const _AttributedQr({
    required this.payload,
    required this.size,
    required this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final url = PrideShareAttribution.attributedPublicUri(payload).toString();
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: QrImageView(
        data: url,
        size: size,
        padding: EdgeInsets.zero,
        backgroundColor: Colors.white,
        semanticsLabel: semanticsLabel,
      ),
    );
  }
}
