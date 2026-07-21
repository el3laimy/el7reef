import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// علامة الحريف المستقلة للمساحات الصغيرة داخل التطبيق.
///
/// تحتفظ العلامة بنسبة العرض الأصلية ولا تضيف خلفية أو ظلًا، حتى يقرر السياق
/// المحيط مستوى الرفع المناسب دون تكرار مؤثرات زخرفية.
class El7reefBrandMark extends StatelessWidget {
  final double size;

  const El7reefBrandMark({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: SvgPicture.asset(
        'assets/brand/brand_mark.svg',
        fit: BoxFit.contain,
        semanticsLabel: 'شعار الحريف',
      ),
    );
  }
}
