import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';

/// Widget الإطار الديناميكي — Task 6.3.3
/// الإطار يتغير تلقائياً حسب التقييم والإنجازات
class DynamicFrameWidget extends StatelessWidget {
  final Widget child;
  final int rating;
  final int mvpCount;
  final bool isTournamentChampion;
  final double size;

  const DynamicFrameWidget({
    super.key,
    required this.child,
    required this.rating,
    this.mvpCount = 0,
    this.isTournamentChampion = false,
    this.size = 80,
  });

  /// نوع الإطار حسب الوثيقة
  _FrameType get _frameType {
    if (isTournamentChampion) return _FrameType.champion;
    if (mvpCount >= 5) return _FrameType.star;
    if (rating >= 1600) return _FrameType.elite;
    if (rating >= 1400) return _FrameType.gold;
    if (rating >= 1200) return _FrameType.silver;
    return _FrameType.newcomer;
  }

  @override
  Widget build(BuildContext context) {
    final frame = _frameType;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── التأثير المضيء (Elite & Champion) ──
          if (frame == _FrameType.elite ||
              frame == _FrameType.champion) ...[
            Container(
              width: size + 8,
              height: size + 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: frame.glowColor.withValues(alpha: 0.6),
                    blurRadius: 16,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),
          ],

          // ── الإطار الرئيسي ──
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: frame.colors,
              ),
              boxShadow: [
                BoxShadow(
                  color: frame.colors.first.withValues(alpha: 0.4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),

          // ── الصورة ──
          ClipOval(
            child: SizedBox(
              width: size - frame.borderWidth * 2,
              height: size - frame.borderWidth * 2,
              child: child,
            ),
          ),

          // ── أيقونة التاج (Champion) ──
          if (frame == _FrameType.champion)
            Positioned(
              top: 0,
              child: Text('👑',
                  style: TextStyle(fontSize: size * 0.22)),
            ),

          // ── أيقونة النجوم (Star) ──
          if (frame == _FrameType.star)
            Positioned(
              bottom: 0,
              child: Text('⭐',
                  style: TextStyle(fontSize: size * 0.22)),
            ),
        ],
      ),
    );
  }
}

/// أنواع الإطار من الوثيقة
enum _FrameType {
  newcomer,
  silver,
  gold,
  elite,
  champion,
  star;

  double get borderWidth => switch (this) {
    newcomer => 2,
    silver => 3,
    gold => 3,
    elite => 4,
    champion => 4,
    star => 4,
  };

  Color get glowColor => switch (this) {
    elite => const Color(0xFFFF8C00),
    champion => const Color(0xFFFFD700),
    star => const Color(0xFF00B4FF),
    _ => Colors.transparent,
  };

  List<Color> get colors => switch (this) {
    // رمادي بسيط
    newcomer => [const Color(0xFF9E9E9E), const Color(0xFF616161)],
    // فضي — برق ولمعان
    silver => [
        const Color(0xFFC0C0C0),
        const Color(0xFF808080),
        const Color(0xFFE8E8E8),
      ],
    // ذهبي
    gold => [
        const Color(0xFFFFD700),
        const Color(0xFFFFA500),
        const Color(0xFFFFD700),
      ],
    // برتقالي متوهج — Elite
    elite => [
        const Color(0xFFFF8C00),
        const Color(0xFFFF4500),
        const Color(0xFFFF8C00),
      ],
    // ذهبي + بنفسجي ملكي — Champion
    champion => [
        const Color(0xFFFFD700),
        const Color(0xFF9400D3),
        const Color(0xFFFFD700),
      ],
    // أزرق نجمي
    star => [
        const Color(0xFF00B4FF),
        const Color(0xFF0040FF),
        const Color(0xFF00B4FF),
      ],
  };

  /// اسم الإطار بالعربي
  String get arabicName => switch (this) {
    newcomer => 'لاعب جديد',
    silver => 'لاعب فضي',
    gold => 'لاعب ذهبي',
    elite => 'لاعب نخبة',
    champion => 'بطل',
    star => 'نجم',
  };
}

/// Preview component — يعرض الإطار الحالي ومتطلبات الارتقاء
class FrameProgressWidget extends StatelessWidget {
  final int rating;
  final int mvpCount;
  final bool isTournamentChampion;

  const FrameProgressWidget({
    super.key,
    required this.rating,
    this.mvpCount = 0,
    this.isTournamentChampion = false,
  });

  @override
  Widget build(BuildContext context) {
    String nextGoal = '';
    if (rating < 1200) {
      nextGoal = 'تقييم ${1200 - rating} نقطة للإطار الفضي';
    } else if (rating < 1400) {
      nextGoal = 'تقييم ${1400 - rating} نقطة للإطار الذهبي';
    } else if (rating < 1600) {
      nextGoal = 'تقييم ${1600 - rating} نقطة لإطار النخبة';
    } else if (!isTournamentChampion) {
      nextGoal = 'افوز ببطولة للحصول على إطار البطل 👑';
    } else {
      nextGoal = 'وصلت لأعلى مستوى! 🏆';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
      ),
      child: Text(
        nextGoal,
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
