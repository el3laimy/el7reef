import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const webPolicyUrl = 'https://el7reef-app.web.app/privacy';
  static const deletionUrl = 'https://el7reef-app.web.app/delete-account';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('سياسة الخصوصية والبيانات')),
        body: ListView(
          padding: const EdgeInsets.all(AppDimensions.pagePadding),
          children: const [
            _PolicySection(
              title: 'آخر تحديث: 29 يوليو 2026',
              body:
                  'تشرح هذه السياسة كيف يعالج تطبيق الحريف بيانات اللاعبين والمنظمين والفرق والبطولات على Android والويب.',
            ),
            _PolicySection(
              title: 'البيانات التي نعالجها',
              body:
                  'بيانات حساب Google اللازمة للدخول، بروفايل اللاعب وصورته واسم المستخدم، عضويات الفرق، بيانات البطولات والمباريات والتشكيلات والأهداف وMVP، وبيانات التواصل الاختيارية للفرق واللاعبين الضيوف. أوقفنا حاليًا تسجيل أحداث الاستخدام من تطبيق Android داخل Firestore حتى اعتماد مسار قياس موثوق ومحدود البيانات؛ وقد تبقى أحداث تاريخية غير متاحة لعميل التطبيق. ويعالج Crashlytics بيانات الأعطال والتشخيص.',
            ),
            _PolicySection(
              title: 'لماذا نستخدمها',
              body:
                  'لتشغيل الحساب، تنظيم الفرق والبطولات، اعتماد النتائج وحماية النزاهة، إنشاء بطاقات الفخر وروابط المطالبة، منع الإساءة، وقياس الأعطال وتحسين الأداء. لا نبيع البيانات الشخصية.',
            ),
            _PolicySection(
              title: 'المشاركة والمعالجون',
              body:
                  'تُعالج البيانات عبر خدمات Firebase من Google مثل Authentication وFirestore وStorage وCloud Functions وCrashlytics وRemote Config. عند اختيار المشاركة، ترسل أنت الصورة أو الرابط إلى التطبيق الذي تختاره مثل WhatsApp أو Instagram وفق سياسة ذلك التطبيق.',
            ),
            _PolicySection(
              title: 'الاحتفاظ والحذف',
              body:
                  'نحتفظ ببيانات الحساب أثناء استخدامه. عند الحذف نزيل تسجيل الدخول والبروفايل والصور والعلاقات الشخصية والرموز النشطة. قد نحتفظ بنتائج المنافسات وسجل التدقيق بعد فصلها عن الحساب لحماية نزاهة البطولات ومنع الاحتيال، ولا يعود لها بروفايل قابل للوصول.',
            ),
            _PolicySection(
              title: 'التحكم في بياناتك',
              body:
                  'يمكنك حذف الحساب من «الحساب والخصوصية» داخل البروفايل بعد إعادة تأكيد Google. ويمكنك أيضًا استخدام صفحة الويب التالية دون التطبيق: https://el7reef-app.web.app/delete-account',
            ),
            _PolicySection(
              title: 'الحماية',
              body:
                  'تُنقل البيانات عبر HTTPS وتُطبق صلاحيات Firebase وعمليات خادم للوظائف الحساسة. لا توجد وسيلة رقمية تضمن حماية مطلقة، لذلك نحد من البيانات ونراجع الصلاحيات دوريًا.',
            ),
            _PolicySection(
              title: 'الأسئلة والشكاوى',
              body:
                  'استخدم صفحة حذف الحساب لطلب إزالة البيانات. ويمكن الإبلاغ عن مستخدم أو محتوى من إجراءات البروفايل، بينما يراجع المنظم نزاعات النتائج من مسار النزاعات داخل التطبيق.',
            ),
          ],
        ),
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  final String title;
  final String body;

  const _PolicySection({required this.title, required this.body});

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
