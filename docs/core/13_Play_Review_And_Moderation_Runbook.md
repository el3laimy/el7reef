<div dir="rtl">

# حزمة مراجعة Google Play ومسار الإشراف على المحتوى

**الحالة:** `VERIFY` — المخرجات المحلية جاهزة، وتنتظر بيانات OWNER والنشر والاختبار المغلق.  
**آخر تحديث:** 12 يوليو 2026

## 1. روابط عامة للمراجع

| الغرض | الرابط |
| :--- | :--- |
| سياسة الخصوصية | `https://el7reef-app.web.app/privacy`&rlm; |
| حذف الحساب دون التطبيق | `https://el7reef-app.web.app/delete-account`&rlm; |
| قواعد المجتمع العامة | `https://el7reef-app.web.app/community-guidelines`&rlm; |
| بريد الدعم الحالي | `jitly9@gmail.com`&rlm; |

نُشرت الروابط الثلاثة في 12 يوليو 2026، وأعيد فحصها عبر HTTPS فكانت `200` وباتجاه RTL&rlm;. يبقى إدخالها في Play Console مسؤولية OWNER&rlm;.

## 2. حزمة حساب المراجع

| الحقل | القيمة |
| :--- | :--- |
| اسم الحزمة | `com.el7reef.app`&rlm; |
| طريقة الدخول | Google Sign-In |
| بريد حساب المراجع | `OWNER-REQUIRED` — لا يجوز وضع حساب شخصي أو اختلاق بيانات |
| كلمة المرور | لا تُكتب في Git؛ توضع في Play Console فقط إذا كانت مطلوبة |
| اسم المستخدم المتوقع | `OWNER-REQUIRED`&rlm; |
| بطولة اختبار جاهزة | `OWNER-REQUIRED` مع 4 فرق على الأقل وفريق زائر |
| QR/Claim صالح | `OWNER-REQUIRED` ويُولد قرب موعد المراجعة لتجنب الانتهاء |
| جهة الاستجابة أثناء المراجعة | `OWNER-REQUIRED`&rlm; |

## 3. خطوات مقترحة للمراجع

1. تسجيل الدخول بحساب Google المخصص للمراجعة بعد قبول قواعد المجتمع وسياسة الخصوصية.
2. فتح «بطولاتي» ثم بطولة الاختبار.
3. فتح مباراة `live` من لوحة «اعمل الآن» وتسجيل نتيجة وهداف زائر وMVP زائر.
4. مراجعة النتيجة ثم فتح Pride Hub ومشاركة Result أو MVP&rlm;.
5. فتح رابط اللاعب الزائر وبدء Claim من الرابط المرفق.
6. فتح بروفايل لاعب مسجل واختبار «الإبلاغ عن البروفايل» و«حظر اللاعب» كإجرائين منفصلين.
7. فتح البروفايل الحالي ثم «الحساب والخصوصية» لرؤية سياسة الخصوصية ومسار حذف الحساب؛ لا يُنفذ الحذف على حساب المراجع إلا في حساب حذف مخصص.
8. رفض إذن الكاميرا في ماسح QR والتحقق من ظهور التفسير وزر «إعادة المحاولة».

## 4. مسار مراجعة البلاغات

تكتب الدالة `reportUserContent` بلاغات موثقة في `userReports` بحالة `open`&rlm;. لا يملك العميل قراءة المجموعة أو كتابتها مباشرة؛ الوصول التشغيلي عبر Firebase Console أو أداة Admin موثوقة فقط.

### الحقول

- الحقل `reporterId`: صاحب البلاغ.
- الحقلان `targetKind` و`targetId`: اللاعب المسجل أو الزائر.
- الحقل `contentType`: حاليًا `profile`&rlm;.
- الحقل `reason`: harassment أو impersonation أو inappropriate أو spam أو other&rlm;.
- الحقل `details`: نص اختياري بحد 500 حرف.
- الحقل `status`: يبدأ `open`&rlm;.
- الحقلان `createdAt` و`updatedAt`: وقتا الإنشاء والتحديث.

### إجراء المراجع التشغيلي

1. فرز البلاغات المفتوحة بالأقدم، مع إعطاء أولوية فورية لسلامة الأطفال والتهديد المباشر.
2. فتح الكيان الهدف ومقارنة المحتوى بالسياق وسجل التدقيق.
3. اختيار نتيجة: `dismissed` أو `content_removed` أو `account_restricted` أو `escalated`&rlm;.
4. تسجيل `reviewedBy` و`reviewedAt` و`resolutionNote` عبر Admin فقط.
5. إزالة أو تصحيح المحتوى المخالف عبر Firebase Admin؛ لا يُستخدم تعديل عميل لتجاوز القواعد.
6. حفظ أقل قدر لازم من تفاصيل البلاغ وفق مدة الاحتفاظ المعتمدة.

**قرار OWNER مطلوب:** تعيين مراجع فعلي واعتماد SLA. المقترح: البلاغ العاجل خلال 24 ساعة، والعادي خلال 72 ساعة، لكنه ليس التزامًا نافذًا قبل الاعتماد.

## 5. مصفوفة الأذونات

| الإذن المتوقع | السبب | لحظة الطلب | رفض الإذن |
| :--- | :--- | :--- | :--- |
| `INTERNET` و`ACCESS_NETWORK_STATE` | Firebase والروابط | نظامي | التطبيق يعرض حالات فشل قابلة للمحاولة |
| `CAMERA` | مسح QR أو التقاط صورة بعد اختيار المستخدم | عند فتح الماسح أو اختيار «التقط صورة» | شاشة تفسير وزر إعادة المحاولة؛ المكتبة تبقى بديلًا للصورة |
| الوصول للصور | Android Photo Picker عبر Image Picker | عند اختيار «من المكتبة» | الإلغاء لا يغير الصورة الحالية |
| الإشعارات | غير مستخدمة في V1 | يجب ألا تظهر بعد إزالة FCM | تحقق Manifest النهائي مطلوب |
| الموقع | غير مستخدم في V1 | لا يُطلب | أزيلت حزم الخرائط والموقع المباشرة |

بُني APK جديد في 12 يوليو 2026 بعد إزالة FCM والخرائط والموقع. اختفت `POST_NOTIFICATIONS` وصلاحيات الموقع والتخزين العام. بقيت `c2dm.RECEIVE` و`WAKE_LOCK` كاعتمادين انتقاليين من `firebase-iid:21.1.0` وفق تقرير Manifest merger؛ لا يعرضان runtime prompt للمستخدم ولم يُحذفا يدويًا حتى لا تُكسر خدمات Firebase المتبقية.

## 6. بوابة Closed Testing

| البوابة | الحالة الحالية | الدليل أو الحاجز |
| :--- | :---: | :--- |
| صفحات السياسة والحذف والمجتمع | `DONE` | منشورة، وHTTPS 200 وRTL مثبتة |
| اختبارات Flutter المحلية | `DONE` | `538 passing` في 12 يوليو 2026 |
| اختبارات Functions المحلية | `DONE` | `27 passing` في 12 يوليو 2026، مع اختبار تحميل entrypoint وعقد audit الآمن |
| Functions Emulator المحلي | `DONE` | 6/6 auth gates وكتابات report/block/audit/delete الموثقة نجحت على Auth/Firestore/Storage demo |
| قواعد Firestore المحلية | `DONE` | `168 passing` على Firestore Emulator في 12 يوليو 2026 |
| نشر Functions | `BLOCKED-EXTERNAL` | مشروع Firebase يحتاج Blaze |
| Release AAB وPlay App Signing | `BLOCKED-EXTERNAL` | يحتاج upload key وبصمة Play من OWNER |
| حساب المراجع وبيانات التواصل | `BLOCKED-EXTERNAL` | لا تُختلق ولا تُحفظ في Git |
| تحقق Android وPilot | `VERIFY` | ثُبت APK على Samsung SM-G980F، وأثبت النظام ملكية App Links وفتح cold/warm. يبقى Release AAB وClaim صالح وlogin وWhatsApp وTalkBack ورحلة Pilot |

### معيار الخروج النهائي

- [ ] حساب المراجع وبيانات التواصل مكتملان في Play Console&rlm;.
- [x] صفحات السياسة والحذف وقواعد المجتمع منشورة وتعيد HTTP 200&rlm;.
- [ ] Functions الخاصة بالحذف والإبلاغ والحظر منشورة وsmoke-tested&rlm;.
- [ ] AAB موقع، وPlay App Signing وassetlinks يحملان بصمة الإصدار.
- [ ] Data Safety مطابقة للـAAB النهائي ووثيقة الجرد.
- [ ] سيناريو البطولة والضيف وClaim يعمل على جهاز Android حقيقي؛ توجيه الروابط مثبت، لكن البيانات الحقيقية والـClaim الصالح لم يُختبرا بعد.
- [ ] رفض الكاميرا والعودة من WhatsApp وTalkBack وtext scale مختبرة.
- [ ] لا crash أو blocker في مسار login ← tournament ← score ← pride ← claim&rlm;.

## 7. أوامر التحقق قبل التسليم

```bash
flutter pub get
dart analyze lib/
flutter test
npm run test:functions
flutter build appbundle --release
npx -y firebase-tools@latest deploy --only hosting
curl --fail --location https://el7reef-app.web.app/privacy
curl --fail --location https://el7reef-app.web.app/delete-account
curl --fail --location https://el7reef-app.web.app/community-guidelines
```

</div>
