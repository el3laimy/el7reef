import 'package:flutter/material.dart';
import '../../domain/entities/player_fantasy_value.dart';

/// ويدجيت فخمة تعرض المستوى الخاص باللاعب (ذهبي، فضي، برونزي)
/// بتصميم عصري ملائم لطبيعة ألعاب الفانتازي (إضاءة داخلية وتأثيرات معدنية)
class TierBadgeWidget extends StatelessWidget {
  /// المستوى المراد عرضه
  final PlayerTier tier;
  
  /// حجم الشارة بالكامل
  final double size;
  
  /// هل يتم عرض النص بجانب الشارة؟ (مثال: "Gold")
  final bool showLabel;

  const TierBadgeWidget({
    super.key,
    required this.tier,
    this.size = 32.0,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    if (showLabel) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildBadge(),
          const SizedBox(width: 8),
          Text(
            _getTierName(),
            style: TextStyle(
              color: _getPrimaryColor(),
              fontWeight: FontWeight.bold,
              fontSize: size * 0.45,
              letterSpacing: 1.2,
            ),
          ),
        ],
      );
    }
    
    return _buildBadge();
  }

  Widget _buildBadge() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: _getTierGradient(),
        boxShadow: [
          BoxShadow(
            color: _getPrimaryColor().withAlpha(102),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.white.withAlpha(25),
            blurRadius: 5,
            spreadRadius: -2,
            offset: const Offset(0, -2), // إضاءة علوية خفيفة لمحاكاة الانعكاس المعدني
          ),
        ],
        border: Border.all(
          color: Colors.white.withAlpha(153),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.star_rounded,
          size: size * 0.65,
          color: Colors.white.withAlpha(230),
        ),
      ),
    );
  }

  /// إرجاع الاسم النصي الاحترافي الخاص بكل مستوى
  String _getTierName() {
    switch (tier) {
      case PlayerTier.gold:
        return 'GOLD';
      case PlayerTier.silver:
        return 'SILVER';
      case PlayerTier.bronze:
        return 'BRONZE';
    }
  }

  /// إرجاع اللون الأساسي الرئيسي
  Color _getPrimaryColor() {
    switch (tier) {
      case PlayerTier.gold:
        return const Color(0xFFFFD700);
      case PlayerTier.silver:
        return const Color(0xFFC0C0C0);
      case PlayerTier.bronze:
        return const Color(0xFFCD7F32);
    }
  }

  /// تدرج لوني انسيابي لكل مستوى معدني يبرز تأثير الـ 3D والفخامة
  LinearGradient _getTierGradient() {
    switch (tier) {
      case PlayerTier.gold:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF275), // فاتح جداً (أصل الانعكاس)
            Color(0xFFFFD700), // ذهبي نقي
            Color(0xFFB8860B), // ذهبي داكن عميق
          ],
          stops: [0.1, 0.5, 0.9],
        );
      case PlayerTier.silver:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFFFF), 
            Color(0xFFD3D3D3), 
            Color(0xFFA9A9A9),
          ],
          stops: [0.1, 0.5, 0.9],
        );
      case PlayerTier.bronze:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE5A675), 
            Color(0xFFCD7F32), 
            Color(0xFF8B4513),
          ],
          stops: [0.1, 0.5, 0.9],
        );
    }
  }
}
