import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Selects the asset with enough contrast for the surface behind the mark.
enum El7reefBrandMarkAppearance { onLight, onDark }

/// علامة الحريف المستقلة للمساحات الصغيرة داخل التطبيق.
///
/// تحتفظ العلامة بنسبة العرض الأصلية ولا تضيف خلفية أو ظلًا، حتى يقرر السياق
/// المحيط مستوى الرفع المناسب دون تكرار مؤثرات زخرفية.
class El7reefBrandMark extends StatelessWidget {
  final double size;
  final El7reefBrandMarkAppearance appearance;

  const El7reefBrandMark({
    super.key,
    required this.size,
    this.appearance = El7reefBrandMarkAppearance.onLight,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: SvgPicture.asset(
        switch (appearance) {
          El7reefBrandMarkAppearance.onLight =>
            'assets/brand/brand_mark_mono_negative.svg',
          El7reefBrandMarkAppearance.onDark => 'assets/brand/brand_mark.svg',
        },
        fit: BoxFit.contain,
        semanticsLabel: 'شعار الحريف',
      ),
    );
  }
}
