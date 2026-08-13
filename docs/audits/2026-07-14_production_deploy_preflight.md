<div dir="rtl">

# تقرير ما قبل نشر إصلاحات المعمارية

> **تنبيه تاريخي:** يوثق هذا التقرير حالة ما قبل النشر بتاريخ 2026-07-14 ولا يمثل قائمة النشر الحالية. أزيل `recordAuditEvent` من المصدر العام ضمن `ELR-SEC-002`، ولم تنفذ هذه الوثيقة أي نشر. يجب اشتقاق أي قائمة نشر أو رجوع جديدة من `docs/core/00_Master_Product_Development_Plan.md` والتدقيق الحالي قبل التنفيذ&rlm;.

**المشروع:** <bdi dir="ltr">el7reef-app</bdi>  
**تاريخ الفحص:** 2026-07-14  
**نوع الفحص:** قراءة ومعاينة فقط؛ لم تُنفذ كتابة أو عملية نشر

## النتيجة التنفيذية

تعذر نشر Cloud Functions لأن المشروع ما زال على الخطة المجانية، ولا يمكن تفعيل <bdi dir="ltr">cloudbuild.googleapis.com</bdi> و<bdi dir="ltr">artifactregistry.googleapis.com</bdi> قبل الترقية إلى Blaze&rlm;. نجحت معاينة قواعد وفهارس Firestore بعد إصلاح ملف الفهارس المحلي ليحافظ على جميع فهارس production الحالية.

## حالة المشروع المثبتة

| البند | الدليل | النتيجة |
| :--- | :--- | :--- |
| قاعدة Firestore | <bdi dir="ltr">firestore:databases:list</bdi> | القاعدة <bdi dir="ltr">(default)</bdi>، إصدار <bdi dir="ltr">STANDARD</bdi>، نوع <bdi dir="ltr">FIRESTORE_NATIVE</bdi>، والموقع <bdi dir="ltr">nam5</bdi> |
| Cloud Functions المنشورة | <bdi dir="ltr">functions:list --json</bdi> | صفر Functions منشورة |
| جرد MatchEvent identity | قراءة حقل <bdi dir="ltr">actor</bdi> فقط | صفر مستندات داخل <bdi dir="ltr">matchEvents</bdi>، ولا توجد أنواع legacy تحتاج migration |
| ترحيل عضويات البطولات | معاينة read-only على منطق الترحيل نفسه | خمس بطولات سليمة، وخمس عضويات منظّم مفقودة، وصفر تعارضات أو مصادر تالفة |
| قواعد Firestore | معاينة نشر مستقلة | الملف المحلي يترجم دون أخطاء |
| الفهارس | مقارنة production بالملف المحلي | تم الحفاظ على 11 فهرسًا منشورًا، وإضافة 8 فهارس جديدة؛ الإجمالي المحلي 19 |
| Functions preflight | <bdi dir="ltr">deploy --dry-run</bdi> | توقف عند شرط Blaze قبل أي نشر |

## نقطة الرجوع قبل النشر

- اسم إصدار القواعد النشط: <bdi dir="ltr">projects/el7reef-app/rulesets/1f5ec089-9fb8-41de-823f-477a37081c4c</bdi>&rlm;.
- اسم release: <bdi dir="ltr">projects/el7reef-app/releases/cloud.firestore</bdi>&rlm;.
- بصمة محتوى القواعد المنشورة: <bdi dir="ltr">fca4803ede82d542e8a9e40b8693897f302f85726eabe3d3e7b651eea9220497</bdi>&rlm;.
- لا يوجد إصدار Functions سابق؛ إذا فشل أول نشر بعد الـsmoke، يكون الرجوع بحذف الوظائف الست الجديدة فقط وإعادة release القواعد إلى ruleset المسجل أعلاه.
- الفهارس الجديدة إضافية ولا تستبدل فهارس production؛ لا تُحذف أثناء rollback العاجل لأن وجودها لا يغير صلاحيات أو نتائج الاستعلامات.

تُفحص استعادة القواعد دون كتابة بالأمر التالي:

<pre dir="ltr"><code>npm run rollback:firestore-rules -- el7reef-app projects/el7reef-app/rulesets/1f5ec089-9fb8-41de-823f-477a37081c4c --dry-run</code></pre>

نجح هذا الأمر وأعاد ruleset النشط نفسه كهدف، دون تحديث release&rlm;.

عند ثبوت فشل الـsmoke فقط، يُعاد الأمر مع <bdi dir="ltr">--apply</bdi>، ثم تُحذف الوظائف الست الجديدة بالأمر التالي:

<pre dir="ltr"><code>npx -y firebase-tools@latest functions:delete submitMatchSettlement approveMatchScore recordAuditEvent deleteAccountData reportUserContent blockUser --region us-central1 --project el7reef-app --force</code></pre>

لا يُستخدم حذف Functions قبل التأكد أن قائمة ما قبل النشر كانت فارغة كما هو موثق في هذا التقرير.

## ترتيب النشر بعد إزالة العائق

1. يرقّي OWNER المشروع إلى Blaze ويضبط budget alerts&rlm;.
2. يؤخذ backup موثق قبل تطبيق ترحيل العضويات الخمس.
3. يُعاد dry-run للترحيل، ثم يُطبق مرة واحدة، ثم تعاد المعاينة لإثبات <bdi dir="ltr">wouldCreate: 0</bdi>&rlm;.
4. تُعاد بوابات الاختبار المحلية وdeploy dry-run&rlm;.
5. تُنشر Functions أولًا، ثم rules/indexes المتوافقة.
6. يُنفذ smoke بحساب OWNER لمباراة بها لاعب مسجل ولاعب زائر بلا lineup&rlm;.
7. تُراقب سجلات <bdi dir="ltr">submitMatchSettlement</bdi> لأخطاء <bdi dir="ltr">INVALID_ARGUMENT</bdi>، مع الفصل بين payload قديم وهوية خارج roster&rlm;.
8. عند فشل الـsmoke، يُنفذ rollback المسجل دون تعديل مباشر لبيانات الإنتاج.

## تحسين اكتُشف أثناء الإصلاح

كان ملف <bdi dir="ltr">firestore.indexes.json</bdi> المحلي لا يحتوي فهارس production القديمة الخاصة بالتحديات والمباريات والدعوات والقوائم. نشره مع حذف الفهارس القديمة كان قد يعطل استعلامات قائمة. أُضيفت الفهارس إلى الملف المحلي، وأضيف <bdi dir="ltr">npm run check:indexes</bdi> إلى CI لمنع حذف baseline المنشور دون قرار صريح.

</div>
