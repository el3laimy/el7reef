import 'claim_code.dart';
import 'claim_payload.dart';

class GeneratedShareLink {
  final ClaimCode claimCode;
  final ClaimPayload payload;
  final Uri appUri;
  final Uri webUri;
  final String qrData;
  final String shareText;
  final String whatsappText;

  const GeneratedShareLink({
    required this.claimCode,
    required this.payload,
    required this.appUri,
    required this.webUri,
    required this.qrData,
    required this.shareText,
    required this.whatsappText,
  });
}
