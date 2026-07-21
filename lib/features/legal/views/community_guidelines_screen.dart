import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';

class CommunityGuidelinesScreen extends StatelessWidget {
  const CommunityGuidelinesScreen({super.key});

  static const webUrl = 'https://el7reef-app.web.app/community-guidelines';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('قواعد مجتمع الحريف')),
        body: ListView(
          padding: const EdgeInsets.all(AppDimensions.pagePadding),
          children: const [
            _GuidelineSection(
              title: 'مجتمع كورة آمن ومحترم',
              body:
                  'باستخدام الحريف، توافق على احترام اللاعبين والمنظمين وعدم نشر بيانات أو صور أو أسماء مسيئة أو مضللة.',
            ),
            _GuidelineSection(
              title: 'المحتوى والسلوك المحظور',
              body:
                  'نحظر التحرش والتنمر وخطاب الكراهية والعنف والتهديد وانتحال الشخصية والرسائل المزعجة والمحتوى الجنسي أو غير القانوني. ويُحظر تمامًا أي محتوى يستغل الأطفال أو يسيء إليهم جنسيًا أو يسهّل ذلك.',
            ),
            _GuidelineSection(
              title: 'الإبلاغ والحظر',
              body:
                  'يمكنك الإبلاغ عن بروفايل أو محتوى من قسم «الأمان» في البروفايل العام، كما يمكنك حظر اللاعب بإجراء منفصل وواضح. لا يظهر اسم المُبلّغ للمستخدم المُبلّغ عنه.',
            ),
            _GuidelineSection(
              title: 'المراجعة والإجراء',
              body:
                  'تُراجع البلاغات وفق خطورتها، وقد نزيل المحتوى أو نقيّد الحساب أو نعلّقه. البلاغات المتعلقة بسلامة الأطفال أو التهديد المباشر تُعامل بأولوية عاجلة وقد تُحال للجهات المختصة وفق القانون.',
            ),
            _GuidelineSection(
              title: 'نزاهة المنافسة',
              body:
                  'يُمنع تزوير النتائج أو انتحال لاعب أو التلاعب بروابط المطالبة. خلافات النتائج تُرفع عبر مسار النزاعات ويُحتفظ بسجل تدقيق لحماية البطولة.',
            ),
          ],
        ),
      ),
    );
  }
}

class _GuidelineSection extends StatelessWidget {
  final String title;
  final String body;

  const _GuidelineSection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.titleMedium),
          const SizedBox(height: AppDimensions.xs),
          Text(
            body,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondaryTinted,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }
}
