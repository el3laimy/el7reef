# وثيقة متطلبات المنتج PRD — El7reef V1: Tournament Ego MVP

**النسخة:** 1.0  
**التاريخ:** 2026-05-02  
**المالك المنتجى:** Project/Product Manager  
**النطاق:** أول إصدار عملي قابل للإطلاق على Google Play  
**مصادر المراجعة:** كود `el7reef-main(1).zip`، أرشيف محادثات المشروع بتاريخ 2026-04-27، وملفات الخطط الحالية داخل المستودع.

---

## 1. الملخص التنفيذي

الحريف ليس تطبيقًا هدفه أن يقول للاعبين: “نزّلوا التطبيق عشان تلعبوا ماتش ودي”. هذا وعد ضعيف؛ لأن اللاعب يستطيع تنظيم الودية عبر واتساب والتقسيمة المعتادة. الوعد الصحيح للإصدار الأول هو:

> **الحريف يحوّل الدورة الشعبية إلى تجربة رسمية، ويحّول اللاعب العادي إلى نجم موثق له اسم، كارت، أرقام، فريق، لحظات، وترتيب يفتخر به ويشاركه.**

بناءً على مراجعة الكود الحالي، يوجد أساس مهم بالفعل: بطولات، فرق، مباريات، لاعبين مسجلين، لاعبين/فرق ضيوف، claim codes، تسجيل هجين، standings، knockout، match settlement، lineups، share cards، audit/disputes. لكن التوجيه القديم في `AGENTS.md` و`docs/implementation_plan.md` كان Friendly Match Core Loop؛ وهذا لا يكفي كسبب تحميل للاعب. لذلك يتم تغيير اتجاه V1 رسميًا إلى:

> **Tournament Ego MVP**

الدورات هي القلب ومحرك الانتشار. الماتش هو وحدة البناء التي تنتج البيانات. البيانات تنتج الفخر. الفخر ينتج المشاركة. المشاركة تجلب لاعبين جدد. الوديات والتحديات تحفظ النشاط بين الدورات.

---

## 2. تعريف المنتج

### 2.1 جملة المنتج

**الحريف** هو تطبيق عربي لكرة الشارع والدورات الشعبية، يساعد المنظمين والكباتن على إنشاء دورات وفرق ومباريات، ويساعد اللاعبين على امتلاك بروفايل وكروت احترافية وإحصائيات قابلة للمشاركة، حتى لو بدأوا داخل النظام كلاعبين ضيوف بدون حساب.

### 2.2 الوعد للمنظم

> “نظّم دورتك الشعبية بشكل يليق ببطولة كبيرة: فرق، لاعبين، جدول، نتائج، ترتيب، هدافين، وكروت جاهزة للمشاركة.”

### 2.3 الوعد للاعب

> “اسمك وأهدافك وفريقك ولحظاتك هتتسجل. العب، اتوثّق، واتفاخر.”

### 2.4 الوعد للكابتن

> “فريقك يبقى له هوية، قائمة، تشكيلة، سجل، تحديات، وكروت تظهره كفريق محترف.”

### 2.5 الوعد للجمهور/الأصحاب

> “تابع الدورة، شوف مين كسب، مين هداف، مين نجم الماتش، ومين طالع للنهائي.”

---

## 3. المشكلة التي يحلها المنتج

### 3.1 مشاكل الدورات الشعبية اليوم

1. النتائج والجداول تضيع بين جروبات واتساب وصور عشوائية.
2. اللاعبين لا يملكون سجلًا أو بروفايل يثبت مشاركاتهم وإنجازاتهم.
3. المنظم يحتاج أن يبدو محترفًا لكنه غالبًا يعمل يدويًا على ورق أو صور غير منظمة.
4. الفرق غير المسجلة واللاعبون غير المسجلين يعرقلون أي تطبيق يفترض أن الجميع لديه حساب.
5. المحتوى الناتج عن الدورة لا يملك جودة بصرية كافية للمشاركة والفخر.
6. الخلافات حول النتيجة أو الهداف أو MVP لا توجد لها آلية واضحة أو audit.

### 3.2 الفرصة النفسية

الدافع الحقيقي ليس “تنظيم”، بل:

- الفخر.
- الـ Ego.
- الاعتراف الاجتماعي.
- المقارنة.
- الانتماء للفريق.
- الظهور في كارت احترافي.
- امتلاك تاريخ رقمي.

اللاعب قد لا يحمّل التطبيق لينظم ماتش، لكنه سيحمّله لو رأى اسمه في ترتيب الهدافين أو كارت MVP أو صفحة فريقه أو رابط claim يقول له: “ده أنت؟ امتلك بروفايلك”.

---

## 4. المستخدمون المستهدفون

### 4.1 منظم الدورة

**الدور:** منشئ الدورة والمتحكم في نظامها.  
**الدوافع:** الهيبة، السيطرة، تقليل الفوضى، إظهار الدورة كمنافسة رسمية.  
**يحتاج إلى:** إنشاء دورة، إضافة/اعتماد فرق، جدولة مباريات، تسجيل نتائج، ترتيب، هدافين، كروت.  
**لحظة القيمة:** أول نتيجة يتم تسجيلها ويخرج منها كارت محترم ينتشر في الجروب.

### 4.2 كابتن الفريق

**الدور:** يمثل الفريق داخل الدورة أو التحدي.  
**الدوافع:** قوة الفريق، السيطرة على القائمة، التحدي، الفخر الجماعي.  
**يحتاج إلى:** إنشاء فريق، إضافة لاعبين، دعوة، تشكيلة، تحديات، صفحة فريق.  
**لحظة القيمة:** كارت الفريق/التشكيلة يظهر وكأنه نادي صغير.

### 4.3 اللاعب

**الدور:** المستفيد النفسي الأساسي.  
**الدوافع:** الظهور، التوثيق، المقارنة، الأهداف، MVP، كارت شخصي.  
**يحتاج إلى:** بروفايل، صورة، مركز، أهداف، مباريات، جوائز، Claim Profile، مشاركة.  
**لحظة القيمة:** يرى اسمه في ترتيب الهدافين أو كارت “نجم المباراة”.

### 4.4 المتابع/الصاحب

**الدور:** يتفاعل مع المحتوى وقد يتحول إلى لاعب أو كابتن.  
**الدوافع:** الفضول، التشجيع، التريقة، المقارنة.  
**يحتاج إلى:** رابط دورة أو كارت واضح بدون تعقيد.  
**لحظة القيمة:** يفتح كارت أو صفحة دورة ويعرف القصة بسرعة.

---

## 5. الرؤية النفسية للمنتج

الحريف يجب أن يبني حلقة نفسية واضحة:

1. **ظهور:** اللاعب يظهر في دورة/فريق/ماتش.
2. **توثيق:** النتيجة والأهداف وMVP تُسجل.
3. **اعتراف:** اللاعب يحصل على لقب أو ترتيب أو كارت.
4. **فخر:** اللاعب يشارك الكارت في واتساب/ستوري.
5. **مقارنة:** باقي اللاعبين يسألون: “أنا ترتيبي كام؟”.
6. **عودة:** اللاعب يفتح التطبيق لمعرفة المباراة القادمة أو تحدي جديد.

---

## 6. أهداف V1

### 6.1 الهدف المنتجى

إطلاق نسخة Android عملية تجعل منظمًا حقيقيًا يستطيع إنشاء دورة شعبية بسيطة، إضافة فرق ولاعبين حتى لو غير مسجلين، تسجيل نتائج وهدافين/MVP، وإخراج محتوى قابل للمشاركة يجذب اللاعبين لعمل Claim لبروفايلاتهم.

### 6.2 الهدف التجاري/النموي

إثبات أن الكروت والـ claim والصفحات العامة/شبه العامة قادرة على جلب لاعبين خارج التطبيق إلى داخله من خلال الدورات.

### 6.3 الهدف التقني

تثبيت الأساس حول كيانات: Tournament, Team, Player, GuestPlayer, GuestTeam, Match, MatchSide, MatchSidePlayer, MatchEvent/Stats, ShareCard, ClaimCode.

---

## 7. مقاييس النجاح

### 7.1 North Star Metric

**عدد الكروت التي تم إنشاؤها ومشاركتها لكل دورة.**

لأن الكارت يعني أن هناك حدثًا، وبيانات، وفخرًا، ومحتوى قابلًا للانتشار.

### 7.2 مؤشرات داعمة

- عدد الدورات المنشأة.
- عدد الفرق لكل دورة.
- عدد اللاعبين الضيوف المضافين.
- نسبة اللاعبين الضيوف الذين عملوا Claim.
- عدد النتائج المسجلة.
- عدد أهداف/أحداث مسجلة لكل مباراة.
- عدد كروت MVP/Result/Top Scorers/Player Card التي تمت مشاركتها.
- عدد التحديات أو الوديات بعد انتهاء الدورة.
- D1/D7 retention للاعبين الذين عملوا Claim.

---

## 8. نطاق V1

### 8.1 داخل النطاق — Must Have

1. إنشاء دورة شعبية بسيطة.
2. إضافة فرق مسجلة أو فرق ضيوف.
3. إضافة لاعبين مسجلين أو ضيوف داخل الفرق.
4. تسجيل/اعتماد فرق داخل الدورة.
5. إنشاء مباريات للدورة أو توليدها بنظام بسيط.
6. بدء مباراة وتسجيل نتيجتها.
7. تسجيل الهدافين وMVP على الأقل.
8. ترتيب الفرق داخل المجموعة/الدورة.
9. ترتيب الهدافين داخل الدورة.
10. صفحة لاعب تعرض الهوية والإنجازات الأساسية.
11. صفحة فريق تعرض الهوية والقائمة والسجل الأساسي.
12. Claim Profile للاعب الضيف.
13. Claim Team للفريق الضيف عند الحاجة.
14. كروت مشاركة: نتيجة، MVP، لاعب، فريق، ترتيب هدافين، مباراة قادمة.
15. تحدي/ودية بسيطة كعنصر نشاط بين الدورات.
16. Arabic RTL first.
17. إخفاء أو تعطيل الفانتازي والأسطح غير الجاهزة.
18. جاهزية Play Store: signing, target SDK, privacy/data safety, closed testing.

### 8.2 داخل النطاق — Should Have

1. اختيار صورة لاعب/فريق.
2. تشكيلة فريق قابلة للمشاركة.
3. اعتراض/تصحيح نتيجة بسيط.
4. Audit واضح لعمليات المنظم.
5. QR أو deep links للـ claim/invite.
6. Empty states قوية وموجهة للفعل.

### 8.3 خارج النطاق في V1

- Fantasy.
- Feed اجتماعي كامل.
- Chat داخلي.
- تقييمات معقدة للاعبين.
- حجوزات ملاعب.
- خرائط متقدمة.
- بث مباشر.
- Monetization.
- أنظمة بطولات كثيرة ومعقدة.
- سوق لاعبين/انتقالات متقدم.

---

## 9. الرحلات الأساسية

### 9.1 رحلة المنظم: إنشاء دورة

1. يفتح تبويب الدورات.
2. يضغط “أنشئ دورة”.
3. يدخل اسم الدورة، المكان، حجم الفريق، عدد الفرق، ونوع بسيط.
4. يضيف فرقًا أو يفتح تسجيل الفرق.
5. يعتمد الفرق.
6. يثبت المشاركين.
7. يولد المجموعات والمباريات.
8. ينشر الجدول.
9. يسجل نتيجة كل مباراة.
10. يرى الترتيب والهدافين.
11. يشارك كروت الدورة.

### 9.2 رحلة الكابتن: إدخال فريق

1. ينشئ فريقًا أو يستلم فريق ضيف.
2. يضيف لاعبين مسجلين أو ضيوف.
3. يسجل الفريق في دورة.
4. يتابع الاعتماد والجدول.
5. يشارك كارت الفريق/التشكيلة.

### 9.3 رحلة اللاعب: Claim وافتخار

1. اللاعب يرى كارت أو رابط فيه اسمه.
2. يفتح الرابط.
3. يرى صفحة claim: “هل أنت فلان؟”.
4. يسجل/يدخل.
5. يمتلك البروفايل الضيف.
6. يرى أهدافه ومبارياته.
7. يشارك كارت اللاعب أو MVP.

### 9.4 رحلة الماتش

1. المباراة موجودة في سياق دورة/تحدي/ودية.
2. الأطراف محددة.
3. القوائم موجودة أو يتم إدخالها سريعًا.
4. المنظم/المصرح له يبدأ المباراة.
5. يسجل النتيجة.
6. يضيف الهدافين وMVP.
7. النتيجة تُعتمد أو تدخل مراجعة.
8. الإحصائيات والleaderboards تتحدث.
9. كروت المشاركة تظهر فورًا.

### 9.5 رحلة العودة بين الدورات

1. فريق ينشئ تحديًا ضد فريق آخر.
2. يسجلون نتيجة.
3. يظهر سجل التحديات في صفحة الفريق.
4. اللاعب يشارك كارت نتيجة أو كارت تحدي.

---

## 10. المتطلبات المنتجية الرئيسية

### 10.1 الدورات

- يجب أن يكون إنشاء الدورة أسرع من 90 ثانية في السيناريو البسيط.
- يجب أن يستطيع المنظم إدارة فرق غير مسجلة.
- يجب أن تظهر الدورة كحدث له صفحة وليس مجرد قائمة.
- يجب إظهار progress واضح: التسجيل، اعتماد الفرق، الجدول، النتائج، الترتيب، البطل.

### 10.2 اللاعب والبروفايل

- اللاعب غير المسجل يجب أن يظهر في النتائج والكروت والهدافين باسم واضح.
- يجب أن يكون له حالة: Guest / Invited / Claimed.
- بعد claim لا تضيع الإحصائيات القديمة.
- البروفايل يجب أن يكون emotional: صورة، لقب، مركز، فريق، أرقام، كروت.

### 10.3 الفريق

- للفريق اسم وشعار/لون وقائد وقائمة.
- الفريق المسجل والفريق الضيف يجب أن يدخلا نفس دورة البطولة بدون إرباك.
- يجب وجود كارت فريق وتشكيلة قابلة للمشاركة.

### 10.4 المباراة

- المباراة هي وحدة البناء لكل النظام.
- كل مباراة لها context: tournament / challenge / friendly.
- النتيجة يجب أن تنتج إحصائيات وكروت.
- تسجيل الأهداف/MVP يجب أن يدعم الضيوف، لا اللاعبين المسجلين فقط.

### 10.5 المشاركة

- يجب أن تظهر أزرار المشاركة في لحظات الفخر، لا داخل menus مخفية.
- كل كارت يجب أن يجيب على سؤال: هل اللاعب سيحبه كستوري؟
- يجب دعم كروت: Result, MVP, Player, Team, Top Scorers, Upcoming Match, Champion.

### 10.6 الثقة والاعتماد

- يجب أن تكون صلاحية تعديل النتيجة واضحة.
- يجب وجود status للنتيجة: Draft/Submitted/Pending Review/Approved/Settled.
- يجب وجود اعتراض بسيط أو سجل audit للأحداث الحساسة.

---

## 11. ما كشفه الكود الحالي

### 11.1 نقاط قوة موجودة

- Flutter + GetX + Firebase بنمط طبقات واضح نسبيًا.
- 367 ملف Dart داخل `lib` مع فصل features/domain/data/core.
- دعم Tournament entity وTournament operations.
- دعم GuestPlayer وGuestTeam وClaimCode.
- ShareLinkService موجود للـ claim/team invite.
- MatchSettlementService موجود لتسجيل واعتماد النتائج.
- MatchdayService موجود للحضور والتشكيلة والتبديلات.
- Lineup engine وshare cards موجودة.
- Firestore rules موجودة وتغطي أغلب المجموعات.
- Fantasy gated عبر `FeatureFlags.fantasyUiEnabled = false`.

### 11.2 فجوات حرجة في ضوء الرؤية الجديدة

- الوثائق القديمة توجه V1 إلى الودية وليس الدورة/الفخر.
- score submit يسجل إحصائيات اللاعبين المسجلين فقط، ويقول صراحة إن اللاعبين المؤقتين لا تُسجل لهم إحصائيات في الودية؛ وهذا يضرب جوهر الفخر للاعب الضيف.
- لا يوجد كيان MatchEvent مستقل في الكود الحالي؛ الإحصائيات تُكتب كـ `player_stats` للمسجلين، وهذا لا يكفي للهدافين والـ MVP عبر guest players.
- كروت المشاركة الحالية تركز على lineup/result، وتحتاج Player/MVP/Top Scorers/Team/Champion cards.
- صفحة البروفايل الحالية تعرض rating وMVP لكنها ليست بعد “كارت نجم شعبي” ولا تربط بشكل قوي بتاريخ الدورات.
- إنشاء الدورة يتيح تفعيل fantasy رغم أن fantasy UI مغلق؛ يجب إخفاء/تعطيل هذا الخيار في V1.
- بعض routes معرفة وغير مسجلة أو غير مستخدمة مثل playerProfile/createTournament/createTeam/leaderboard/achievements/myQrCode.
- Android release يستخدم debug signing حاليًا؛ هذا مانع Play Store.

---

## 12. فرضيات المنتج

1. اللاعب سيقوم بالتحميل عندما يرى اسمه أو صورته أو ترتيبه في سياق دورة.
2. المنظم سيستخدم التطبيق لو اختصر له العمل وأظهر دورته بشكل رسمي.
3. كروت المشاركة هي أقوى قناة اكتساب مجانية.
4. دعم الضيوف والـ claim هو شرط واقعي لا غنى عنه.
5. أي feature لا تنتج فخرًا أو ثقة أو مشاركة ليست أولوية لـ V1.

---

## 13. Release Gate المنتجى

لا نطلق V1 قبل تحقق الآتي:

1. دورة كاملة يمكن إنشاؤها وتشغيلها حتى أول نتيجة وترتيب.
2. فريق ضيف ولاعب ضيف يمكن إضافتهما وربطهما لاحقًا بحساب.
3. نتيجة مباراة يمكن أن تشمل هدافين وMVP من guest أو registered players.
4. ظهور ترتيب فرق وهدافين حقيقيين.
5. وجود كروت مشاركة واضحة وجميلة لأهم لحظات الفخر.
6. تجربة claim تعمل من رابط/QR.
7. لا توجد أزرار fake أو “قريبًا” داخل المسار الأساسي.
8. التطبيق جاهز تقنيًا للـ Play Store.

---

## 14. التموضع التسويقي

### 14.1 رسالة المتجر

**الحريف — دورتك الشعبية بشكل دوري محترفين**

### 14.2 وصف قصير

نظّم دورتك، سجّل الفرق واللاعيبة والنتائج، واعمل كروت احترافية للهدافين والنجوم.

### 14.3 رسائل جذب للاعب

- “اسمك فين في ترتيب الهدافين؟”
- “إنت نجم الماتش؟ اثبتها.”
- “اعمل Claim لبروفايلك وخلي أهدافك تتحسب.”
- “كارتك كلاعب جاهز للمشاركة.”

### 14.4 رسائل جذب للمنظم

- “اعمل لدورتك صفحة وجدول وترتيب وكروت.”
- “دورتك الشعبية بشكل رسمي.”
- “من أول فريق لحد البطل — كله متوثق.”

---

## 15. القرار النهائي

**إصدار Play Store الأول للحريف يجب أن يكون Tournament Ego MVP.**

الوديات والتحديات مهمة، لكن ليست قلب الرسالة. القلب هو الدورات، والفخر، والكروت، واللاعب الذي يجد نفسه نجمًا داخل نظام موثق.
# مواصفات متطلبات البرنامج SRS — El7reef V1

**النسخة:** 1.0  
**التاريخ:** 2026-05-02  
**النطاق:** المتطلبات الوظيفية وغير الوظيفية لأول إصدار Play Store  
**الاتجاه المنتجى:** Tournament Ego MVP

---

## 1. الغرض

هذه الوثيقة تحول الرؤية المنتجية للحريف إلى متطلبات برمجية قابلة للتنفيذ والاختبار. الهدف هو توجيه التطوير نحو إصدار أول عملي يتمحور حول الدورات الشعبية والفخر والـ claim والكروت، مع الحفاظ على الوديات والتحديات كمسارات نشاط بين الدورات.

---

## 2. نطاق النظام

النظام تطبيق Flutter Android/iOS مستقبلاً، يعتمد حاليًا على Firebase وGetX. V1 يستهدف Android/Google Play أولاً.

النظام يجب أن يدعم:

- المستخدم المسجل.
- اللاعب الضيف.
- الفريق المسجل.
- الفريق الضيف.
- الدورة.
- المباراة.
- أحداث المباراة.
- الإحصائيات.
- الكروت القابلة للمشاركة.
- claim/invite links.
- صلاحيات المنظم والكابتن واللاعب.

---

## 3. تعريفات

| المصطلح | التعريف |
|---|---|
| Tournament | دورة/مسابقة شعبية لها فرق ومباريات وترتيب. |
| Match | وحدة البناء: مباراة داخل دورة أو تحدي أو ودية. |
| GuestPlayer | لاعب غير مسجل أضيف يدويًا ويمكنه عمل claim لاحقًا. |
| GuestTeam | فريق غير مسجل أو مُدار مؤقتًا داخل دورة. |
| Claim | عملية ربط كيان ضيف بحساب حقيقي. |
| Share Card | صورة/كارت قابل للمشاركة على واتساب/السوشيال. |
| MVP | نجم المباراة. |
| MatchEvent | حدث داخل المباراة مثل Goal أو Assist أو MVP. |

---

## 4. الحالة الحالية من الكود

### 4.1 مكونات موجودة

- `Tournament`, `TournamentParticipant`, `TournamentGroup`, `GroupStandingSnapshot`, `KnockoutBracket`, `KnockoutTie`.
- `Match`, `MatchSide`, `MatchSidePlayer`, `MatchLineupSnapshot`.
- `GuestPlayer`, `GuestTeam`, `ClaimCode`, `ClaimPayload`.
- Services: `TournamentLifecycleService`, `TournamentRegistrationService`, `TournamentParticipantService`, `MatchSettlementService`, `MatchdayService`, `ShareLinkService`, `GuestClaimService`, `TeamRosterService`.
- Shareables: `LineupShareCard`, `MatchResultShareCard`, `ShareCardCaptureService`.
- Feature flags: fantasy متوقف، guest identity مفعل، hybrid tournament registration مفعل.

### 4.2 قيود حالية يجب علاجها

- عدم وجود `MatchEvent` مستقل يدعم guest players.
- إحصائيات score submission مرتبطة باللاعبين المسجلين فقط.
- player profile ليس بعد مركز الفخر الأساسي.
- لا يوجد player card/MVP card/top scorers card بشكل مكتمل.
- بعض routes معرفة بدون registration أو usage.
- Android release signing غير جاهز.
- Create Tournament UI يعرض fantasy toggle رغم إيقاف fantasy UI.

---

## 5. المتطلبات الوظيفية

### 5.1 الحساب والدخول

**FR-AUTH-001** يجب أن يستطيع المستخدم تسجيل الدخول بحساب Google كما هو مدعوم حاليًا.  
**FR-AUTH-002** يجب إنشاء/تحميل Player profile بعد الدخول.  
**FR-AUTH-003** يجب منع العمليات الحساسة بدون `actorId`.  
**FR-AUTH-004** يجب أن يدعم النظام deep links للـ claim/invite حتى لو احتاج المستخدم تسجيل دخول قبل الإكمال.

### 5.2 بروفايل اللاعب

**FR-PLAYER-001** يجب عرض بروفايل لاعب يحتوي الاسم، الصورة، المركز، الرقم/الألقاب لاحقًا، الفرق، المباريات، الأهداف، MVP، والإنجازات.  
**FR-PLAYER-002** يجب أن يدعم البروفايل لاعبًا مسجلًا ولاعبًا ضيفًا قبل claim.  
**FR-PLAYER-003** يجب أن يظهر زر “شارك كارت اللاعب” عند توفر بيانات كافية.  
**FR-PLAYER-004** يجب أن يعرض البروفايل حالة البيانات: موثقة/قيد المراجعة/ضيف.  
**FR-PLAYER-005** يجب ألا تضيع إحصائيات guest player بعد claim.

### 5.3 الفرق

**FR-TEAM-001** يجب أن يستطيع المستخدم إنشاء فريق باسم وشعار/لون اختياري.  
**FR-TEAM-002** يجب أن يستطيع الكابتن إضافة لاعب مسجل أو لاعب ضيف.  
**FR-TEAM-003** يجب أن يستطيع الكابتن مشاركة رابط انضمام أو claim للاعب ضيف.  
**FR-TEAM-004** يجب عرض قائمة الفريق، القائد، اللاعبين، السجل، والتشكيلة.  
**FR-TEAM-005** يجب أن يدعم الفريق كارت مشاركة للفريق والتشكيلة.  
**FR-TEAM-006** يجب أن تعمل إدارة الفريق مع `teamMemberships` و`guestPlayers` بدون تضارب.

### 5.4 الدورات

**FR-TOUR-001** يجب أن يستطيع المستخدم إنشاء دورة باسم، وصف اختياري، موقع اختياري، حجم فريق، عدد فرق، ونظام بسيط.  
**FR-TOUR-002** يجب إخفاء fantasy toggle من إنشاء الدورة في V1 أو جعله disabled بوضوح.  
**FR-TOUR-003** يجب عرض صفحة دورة فيها الحالة، الفرق، الجدول، النتائج، الترتيب، الهدافين، والكروت.  
**FR-TOUR-004** يجب أن يستطيع المنظم إضافة/اعتماد فرق مسجلة وضيوف.  
**FR-TOUR-005** يجب أن يستطيع المنظم تثبيت participant list قبل توليد الجدول.  
**FR-TOUR-006** يجب أن يستطيع النظام توليد مجموعات ومباريات لنظام بسيط.  
**FR-TOUR-007** يجب أن يستطيع المنظم نشر fixtures.  
**FR-TOUR-008** يجب تحديث standings بعد اعتماد نتائج مباريات المجموعات.  
**FR-TOUR-009** يجب تحديث knockout progress بعد اعتماد نتائج الإقصاء.  
**FR-TOUR-010** يجب إعلان البطل وإخراج كارت البطل.

### 5.5 التسجيل الهجين والضيوف

**FR-GUEST-001** يجب أن يستطيع المنظم أو الكابتن إنشاء GuestTeam.  
**FR-GUEST-002** يجب أن يستطيع المنظم أو الكابتن إنشاء GuestPlayer.  
**FR-GUEST-003** يجب أن يكون لكل guest حالة: guest, invited, claimed, archived.  
**FR-GUEST-004** يجب إنشاء claim code آمن بصلاحية زمنية.  
**FR-GUEST-005** يجب أن يستطيع اللاعب فتح رابط claim ورؤية بياناته قبل الربط.  
**FR-GUEST-006** يجب أن يمنع النظام claim غير مصرح به أو منتهي.  
**FR-GUEST-007** يجب ربط guest player بحساب Player دون حذف التاريخ.

### 5.6 المباريات

**FR-MATCH-001** يجب أن يكون لكل مباراة type أو context واضح: tournament/challenge/friendly.  
**FR-MATCH-002** يجب أن تدعم المباراة فرقًا رسمية أو sides مؤقتة.  
**FR-MATCH-003** يجب أن يستطيع المصرح له بدء المباراة فقط إذا الحالة تسمح.  
**FR-MATCH-004** يجب ألا يسمح بتغيير teamSize بعد قفل أي lineup snapshot.  
**FR-MATCH-005** يجب أن تعرض المباراة أسماء الأطراف من teams أو matchSides.  
**FR-MATCH-006** يجب أن تدعم المباراة لاعبًا مسجلًا أو ضيفًا كطرف إحصائي.  
**FR-MATCH-007** يجب أن يكون تسجيل النتيجة متاحًا في status مناسب فقط.  
**FR-MATCH-008** يجب تسجيل scoreA/scoreB وcompletedAt وstatus.

### 5.7 أحداث المباراة والإحصائيات

**FR-EVENT-001** يجب إضافة كيان `MatchEvent` في V1 أو مرحلة تأسيسية قبل إطلاق الدورات.  
**FR-EVENT-002** يجب دعم event types مبدئيًا: goal, assist(optional), mvp, ownGoal(optional).  
**FR-EVENT-003** يجب أن يقبل event actor لاعبًا مسجلًا أو guest player أو matchSidePlayer.  
**FR-EVENT-004** يجب أن تُشتق ترتيب الهدافين من أحداث الأهداف لا من حقول مشتتة.  
**FR-EVENT-005** يجب منع مجموع أهداف الهدافين من تجاوز score إلا بتحذير/استثناء مقصود.  
**FR-EVENT-006** يجب أن يسمح MVP بالاختيار من كل لاعبي المباراة، وليس المسجلين فقط.  
**FR-EVENT-007** يجب كتابة snapshot مبسط للإحصائيات بعد اعتماد النتيجة لتحسين القراءة.

### 5.8 التشكيلات

**FR-LINEUP-001** يجب أن يدعم Lineup Editor أحجام 5 إلى 11.  
**FR-LINEUP-002** يجب أن يكون `match.teamSize` مصدر الحقيقة.  
**FR-LINEUP-003** يجب أن يكون `formationCode` للاعبين خارج الحارس فقط.  
**FR-LINEUP-004** يجب أن تظهر التشكيلة للاعبين المسجلين والضيوف.  
**FR-LINEUP-005** يجب أن تبقى التشكيلة اختيارية في الوديات والتحديات، وقد تكون مطلوبة في مباريات الدورة حسب إعداد المنظم.  
**FR-LINEUP-006** يجب عرض CTA واضح لمشاركة التشكيلة بعد الحفظ.

### 5.9 الكروت والمشاركة

**FR-SHARE-001** يجب وجود ShareCardCaptureService أو بديل مستقر لالتقاط الكروت.  
**FR-SHARE-002** يجب دعم Result Card.  
**FR-SHARE-003** يجب دعم Lineup Card.  
**FR-SHARE-004** يجب دعم Player Card.  
**FR-SHARE-005** يجب دعم MVP Card.  
**FR-SHARE-006** يجب دعم Top Scorers Card.  
**FR-SHARE-007** يجب دعم Team Card.  
**FR-SHARE-008** يجب دعم Champion Card عند نهاية الدورة.  
**FR-SHARE-009** يجب أن تظهر أزرار المشاركة بعد لحظات الفخر مباشرة.  
**FR-SHARE-010** يجب أن يعمل share fallback عند فشل التقاط الصورة.

### 5.10 التحديات والوديات

**FR-CHAL-001** يجب أن يستطيع فريق تحدي فريق آخر.  
**FR-CHAL-002** يجب أن تنتج التحديات مباراة بنفس نموذج match العام.  
**FR-CHAL-003** يجب تسجيل نتيجة التحدي وإظهارها في سجل الفريق.  
**FR-FRIEND-001** يجب أن يستمر إنشاء ودية سريعًا، لكن لا يكون هو الرسالة الأساسية للتطبيق.  
**FR-FRIEND-002** يجب أن تنتج الودية كارت نتيجة وتدعم لاعبين ضيوف.

### 5.11 الثقة والاعتراضات

**FR-TRUST-001** يجب أن يملك النظام audit events للعمليات الحساسة.  
**FR-TRUST-002** يجب دعم dispute بسيط على نتيجة/إحصائية.  
**FR-TRUST-003** يجب أن تظهر حالة النتيجة للمستخدم بوضوح.  
**FR-TRUST-004** يجب أن يكون اعتماد النتيجة بيد المنظم أو صاحب الصلاحية.  
**FR-TRUST-005** يجب الاحتفاظ بـ before/after payload في audit عند الإمكان.

---

## 6. المتطلبات غير الوظيفية

### 6.1 الأداء

**NFR-PERF-001** فتح الرئيسية يجب أن يكون سريعًا ولا ينتظر كل بيانات التطبيق.  
**NFR-PERF-002** صفحات الدورة يجب أن تحمل الأقسام تدريجيًا.  
**NFR-PERF-003** الكروت يجب أن تُلتقط بجودة مناسبة خلال زمن مقبول.  
**NFR-PERF-004** يجب تجنب queries غير مفهرسة أو واسعة جدًا.

### 6.2 الاعتمادية

**NFR-REL-001** يجب ألا ينهار التطبيق عند نقص بيانات اختيارية مثل logoUrl/photoUrl.  
**NFR-REL-002** العمليات الحساسة يجب أن تكون transaction أو batch عند الحاجة.  
**NFR-REL-003** يجب منع states غير منطقية مثل score لمباراة open أو standings بدون fixtures.  
**NFR-REL-004** يجب أن تكون الأخطاء بالعربية ومفهومة.

### 6.3 الأمن والصلاحيات

**NFR-SEC-001** يجب أن تمنع Firestore rules أي write مجهول.  
**NFR-SEC-002** يجب ألا يعتمد الأمن على UI فقط.  
**NFR-SEC-003** يجب أن تستخدم claim codes status/expiry/target validation.  
**NFR-SEC-004** يجب منع تغيير owner/organizer fields بعد الإنشاء إلا بصلاحيات واضحة.  
**NFR-SEC-005** يجب تدقيق permissions للكاميرا/الصور/location قبل Play Store.

### 6.4 الخصوصية

**NFR-PRI-001** يجب تقليل البيانات الشخصية المطلوبة في البداية.  
**NFR-PRI-002** رقم الهاتف اختياري ولا يظهر علنًا افتراضيًا.  
**NFR-PRI-003** يجب كتابة Privacy Policy متوافقة مع Firebase/Auth/Analytics/Storage/Image Picker.  
**NFR-PRI-004** يجب ملء Data Safety بدقة.

### 6.5 قابلية الصيانة

**NFR-MAINT-001** يجب عدم إضافة writes مباشرة في controllers للعمليات الحساسة إذا توجد service.  
**NFR-MAINT-002** يجب فصل UI عن domain logic قدر الإمكان.  
**NFR-MAINT-003** يجب إضافة tests للـ services قبل توسيع UI.  
**NFR-MAINT-004** يجب تقليل feature flags المضللة.

### 6.6 تجربة المستخدم

**NFR-UX-001** Arabic RTL first.  
**NFR-UX-002** لا توجد أزرار dead أو قريبًا في المسار الأساسي.  
**NFR-UX-003** أي صفحة فارغة يجب أن تحتوي CTA واضح.  
**NFR-UX-004** المشاركة يجب أن تكون one tap قدر الإمكان.

---

## 7. نموذج الصلاحيات

| الدور | الصلاحيات الأساسية |
|---|---|
| Organizer | إنشاء دورة، اعتماد فرق، تثبيت المشاركين، توليد مباريات، تسجيل/اعتماد النتائج، إدارة disputes. |
| Assistant | صلاحيات محددة حسب role: نتائج/فرق/إعدادات. |
| Captain | إدارة فريقه، إضافة لاعبين، تسجيل فريقه، مشاركة دعوات. |
| Player | Claim profile، مشاهدة بروفايله، مشاركة كروته، الاعتراض على إحصائية. |
| Guest | يظهر داخل النظام بدون حساب إلى أن يتم claim. |
| Spectator | قراءة محتوى عام/شبه عام حسب إعدادات الخصوصية. |

---

## 8. متطلبات البيانات

### 8.1 مجموعات موجودة يجب الحفاظ عليها

- players
- guestPlayers
- teams
- guestTeams
- teamMemberships
- matches
- matchSides
- matchSidePlayers
- matchLineupSnapshots
- tournaments
- tournamentRegistrations
- tournamentParticipants
- tournamentGroups
- groupStandingSnapshots
- knockoutBrackets
- knockoutTies
- claimCodes
- auditEvents
- disputes
- analyticsEvents

### 8.2 مجموعات/نماذج موصى بإضافتها لـ V1

#### matchEvents

الحقول المقترحة:

- id
- matchId
- tournamentId nullable
- eventType: goal/mvp/assist/ownGoal
- sideKey
- participantRef: `{kind: player|guestPlayer|matchSidePlayer, id, displayNameSnapshot}`
- minute nullable
- createdBy
- createdAt
- status: active/voided/pending

#### playerCareerStats أو playerTournamentStats

يفضل بناء snapshots مشتقة لتسريع القراءة:

- playerKey
- displayNameSnapshot
- tournamentId nullable
- teamId/guestTeamId nullable
- matches
- goals
- assists
- mvpCount
- wins/draws/losses
- updatedAt

#### shareCardEvents

لتتبع النمو:

- id
- cardType
- entityType
- entityId
- actorId
- tournamentId nullable
- matchId nullable
- createdAt

---

## 9. واجهات خارجية

- Firebase Auth.
- Cloud Firestore.
- Firebase Storage للصور.
- Firebase Analytics اختياري لكن موجود.
- Google Sign-In.
- share_plus للمشاركة.
- image_picker للصور.
- QR/mobile_scanner للـ QR.
- Google Maps/Location موجودة لكن ليست محور V1.

---

## 10. معايير القبول للإصدار

### 10.1 دورة كاملة

- إنشاء دورة.
- إضافة فريق مسجل وفريق ضيف.
- إضافة لاعبين ضيوف.
- اعتماد المشاركين.
- توليد مباراة.
- بدء المباراة.
- تسجيل نتيجة + هدافين + MVP.
- تحديث ترتيب وهدافين.
- مشاركة كارت نتيجة وكارت MVP.
- لاعب ضيف يعمل Claim بدون فقدان هدفه.

### 10.2 استقرار تقني

- `flutter pub get` يعمل.
- `dart analyze lib/` بدون issues.
- `flutter test` للـ core services ينجح أو توثق أي اختبارات مؤجلة.
- release build موقّع signing release وليس debug.
- Firestore rules محدثة ومختبرة.
- لا routes مكسورة في navigation الأساسي.

### 10.3 جاهزية المتجر

- App name/icon/label مضبوط.
- target SDK مطابق لمتطلبات Google Play.
- Privacy Policy وData Safety جاهزين.
- closed testing منظم قبل production عند الحاجة.

---

## 11. مصفوفة تتبع مختصرة

| هدف PRD | متطلب SRS | ملاحظات كود حالية |
|---|---|---|
| الدورات هي القلب | FR-TOUR-* | أساس موجود ويحتاج UX وshare/leaderboards أقوى. |
| الفخر والـ Ego | FR-SHARE, FR-PLAYER | result/lineup cards موجودة؛ player/MVP/top scorers ناقصة. |
| الضيوف first-class | FR-GUEST, FR-EVENT | guest models/claim موجود؛ stats/events للضيوف ناقصة. |
| الماتش وحدة بناء | FR-MATCH, FR-EVENT | Match قوي؛ يحتاج context/type أو توحيد أوضح وMatchEvent. |
| الثقة | FR-TRUST | audit/dispute موجودان؛ يحتاجان ربط UX بالإحصائيات. |

---

## 12. قرار SRS النهائي

لا يتم اعتبار V1 جاهزًا لو ظل اللاعب الضيف غير قادر على الحصول على هدف/MVP/كارت/claim. هذا هو الفارق بين تطبيق تنظيم وبين منصة فخر وانتشار.
# وثيقة هيكلية النظام والتصميم عالي المستوى SAD — El7reef V1

**النسخة:** 1.0  
**التاريخ:** 2026-05-02  
**النطاق:** المعمارية الحالية والمستهدفة لأول إصدار Play Store  
**الاتجاه المنتجى:** Tournament Ego MVP

---

## 1. الهدف من الوثيقة

هذه الوثيقة تصف معمارية الحريف الحالية كما تظهر في الكود، وتقترح التصميم عالي المستوى المطلوب للوصول إلى V1. الهدف هو منع التشتت والتأكد أن كل تطوير جديد يخدم النظام المركزي: الدورات، المباريات، الأحداث، الإحصائيات، الكروت، والـ claim.

---

## 2. نظرة عامة على المعمارية الحالية

المشروع مبني بـ:

- Flutter.
- GetX للـ routing/state/dependency injection.
- Firebase Auth / Firestore / Storage / Messaging / Analytics.
- طبقات واضحة نسبيًا:
  - `lib/features`: UI/controllers/bindings.
  - `lib/domain`: entities/repositories interfaces.
  - `lib/data`: models/repository implementations.
  - `lib/core`: services/enums/widgets/lineup/theme/constants.
  - `lib/app`: routes/theme.

### 2.1 حجم الكود المراجع

- `lib`: 367 ملف Dart، حوالي 65k سطر.
- `test`: 52 ملف، حوالي 13k سطر.
- `firestore.rules`: 667 سطر.
- docs/md داخل المستودع: 27 ملف تقريبًا.

> لم يتم تشغيل Flutter/Dart داخل هذه البيئة لأن أدوات flutter/dart غير متاحة هنا. يوجد داخل المستودع `analysis_report.txt` يذكر أن تحليلًا سابقًا خرج بـ “No issues found”. يجب إعادة تشغيل الأوامر محليًا قبل أي release.

---

## 3. مكونات النظام الحالية

### 3.1 App Layer

- `main.dart`: تهيئة Firebase، تسجيل AuthService، GetMaterialApp، RTL Arabic، dark theme.
- `app_routes.dart`: route constants.
- `app_pages.dart`: GetPages وتعطيل بعض features عبر FeatureUnavailableScreen.

### 3.2 Feature Modules

| Feature | الحالة الحالية | ملاحظات |
|---|---|---|
| Auth | Login/Onboarding/Profile أساس موجود | يحتاج ربط أوضح بـ claim onboarding. |
| Home | 5 tabs: الرئيسية، اكتشاف، دورات، فرقي، بروفايل | يجب إعادة ترتيب الرسالة حول الدورات والفخر. |
| Tournament | list/detail/registration/operations/groups/fixtures/standings/bracket/assistants | أساس قوي لكن UX تشغيلي أكثر من emotional. |
| Match | discover/lobby/matchday/score/fan voting/challenges | قوي للودية، يحتاج توحيد حول match events. |
| Team | my teams/roster/guest members/invites | مهم جدًا ويحتاج team identity card. |
| Guest Claim | claim player/team/invite entry | foundation مهم للنمو. |
| Lineup | editors/result lineup/share | جيد ويحتاج ربط tournament/team pride. |
| Shareables | result/lineup cards | يحتاج توسيع إلى player/MVP/top scorers/champion. |
| Fantasy | موجود لكن gated | خارج V1. |
| Social | friends/search/activity feed | ليس قلب V1. |
| Organizer | audit/disputes | مفيد للثقة. |

---

## 4. مبادئ التصميم المستهدفة

1. **Match هو وحدة البناء:** كل دورة/تحدي/ودية تنتج مباراة أو أكثر.
2. **Events هي مصدر الإحصائيات:** لا نعتمد على حقول متفرقة فقط للأهداف والـ MVP.
3. **Guest-first:** اللاعب أو الفريق غير المسجل يشارك كاملًا، ثم يعمل claim لاحقًا.
4. **Trust by design:** audit وpermissions وstatus واضحة.
5. **Share by design:** كل لحظة مهمة تنتج كارت.
6. **Feature gates صريحة:** لا fantasy ولا fake surfaces داخل V1.
7. **Services مركزية:** العمليات الحساسة داخل services لا controllers.

---

## 5. التصميم عالي المستوى المستهدف

```text
┌─────────────────────────────────────────┐
│                 Flutter UI              │
│ Screens / Widgets / Share Cards / RTL   │
└────────────────────┬────────────────────┘
                     │ GetX Controllers
┌────────────────────▼────────────────────┐
│            Application Services          │
│ TournamentLifecycle / MatchSettlement   │
│ MatchEventService / ShareCardService    │
│ GuestClaim / TeamRoster / Permissions   │
└────────────────────┬────────────────────┘
                     │ Repositories
┌────────────────────▼────────────────────┐
│              Domain Layer                │
│ Entities: Tournament, Match, Team,       │
│ Player, GuestPlayer, MatchEvent, Stats   │
└────────────────────┬────────────────────┘
                     │ Models + Firestore
┌────────────────────▼────────────────────┐
│              Firebase Backend            │
│ Auth / Firestore / Storage / Analytics   │
│ Security Rules / Indexes                 │
└─────────────────────────────────────────┘
```

---

## 6. الكيانات الأساسية

### 6.1 Tournament

موجود حاليًا ويمثل الدورة. يحتوي على organizerId, name, format, teamSize, maxTeams, status, assistants, participant summary, current stages, winner.

**تحسين مستهدف:** إضافة presentation fields اختيارية مثل coverImageUrl, accentColor, publicSlug لاحقًا.

### 6.2 Team / GuestTeam

Team يمثل فريقًا رسميًا. GuestTeam يمثل فريقًا مؤقتًا قابلًا للـ claim.

**تحسين مستهدف:** توحيد طريقة العرض عبر TeamIdentity DTO حتى لا تتكرر حالات official/guest داخل UI.

### 6.3 Player / GuestPlayer

Player هو حساب حقيقي. GuestPlayer هو لاعب مضاف يدويًا.

**تحسين مستهدف:** بناء PlayerIdentityRef:

```text
PlayerIdentityRef
- kind: registered | guest | matchSidePlayer
- id
- displayNameSnapshot
- photoUrlSnapshot?
- linkedPlayerId?
```

### 6.4 Match

موجود حاليًا ويحتوي tournament fields وteam ids وstatus والنتيجة.

**تحسين مستهدف:** إضافة/توحيد context:

```text
matchType: tournament | challenge | friendly
contextId: tournamentId/challengeId/null
```

أو الاكتفاء بـ `tournamentId` + challenge relation في V1 مع توثيق واضح.

### 6.5 MatchSide / MatchSidePlayer

موجودان ويدعمان sides مؤقتة ولاعبين داخل طرف المباراة. هذه نقطة قوة مهمة ويجب استخدامها كأساس للأحداث والـ share.

### 6.6 MatchEvent — إضافة مطلوبة

الكيان الناقص الأهم.

```text
MatchEvent
- id
- matchId
- tournamentId?
- eventType: goal | assist | mvp | ownGoal | card
- sideKey: A | B
- actor: PlayerIdentityRef
- assistedBy: PlayerIdentityRef?
- minute?
- createdBy
- createdAt
- status: active | voided | pendingReview
- source: organizer | captain | migration
```

### 6.7 Derived Stats

إحصائيات مشتقة من MatchEvents:

- TournamentScorerStanding.
- PlayerTournamentStats.
- TeamTournamentStats.
- PlayerCareerStats.

يمكن تخزينها كسnapshots لتحسين الأداء.

---

## 7. Firestore collections المقترحة

### 7.1 موجودة ومستخدمة

```text
players
guestPlayers
teams
guestTeams
teamMemberships
teamFormationTemplates
teamRosterSnapshots
matches
matchSides
matchSidePlayers
matchCheckIns
matchAttendances
matchLineupSnapshots
matchSubstitutions
tournaments
tournamentRegistrations
tournamentParticipants
tournamentGroups
groupStandingSnapshots
knockoutBrackets
knockoutTies
claimCodes
fanVotingSessions
userVotes
auditEvents
disputes
analyticsEvents
```

### 7.2 مطلوبة/موصى بها لـ V1

```text
matchEvents
playerTournamentStats
teamTournamentStats
tournamentScorerSnapshots
shareCardEvents
```

### 7.3 سبب إضافة matchEvents

الكود الحالي يسجل `player_stats` تحت `matches/{matchId}` للاعبين المسجلين فقط. هذا لا يكفي لأن المنتج الجديد يعتمد على guest players والـ Ego. يجب أن يكون الهدف أو MVP قابلًا للنسبة إلى لاعب ضيف أو matchSidePlayer وليس فقط Player document.

---

## 8. تدفقات النظام الأساسية

### 8.1 إنشاء دورة

```text
UI CreateTournamentSheet
→ TournamentController.createTournament
→ TournamentRepositoryImpl.createTournament
→ Firestore tournaments
→ TournamentList/Detail reload
```

**تعديل مطلوب:** إزالة fantasy toggle من UI أو إجباره false في V1.

### 8.2 تسجيل فريق ضيف في دورة

```text
TournamentRegistrationScreen
→ TournamentGuestTeamCreateController
→ GuestTeamRepository / TournamentRegistrationService
→ tournamentRegistrations
→ tournamentParticipants after approval/sync
→ optional ShareLinkService.createGuestTeamClaimLink
```

### 8.3 إضافة لاعب ضيف للفريق

```text
TeamRosterScreen
→ TeamRosterController.createGuestPlayerAndAdd
→ GuestPlayerRepository + TeamMembershipRepository
→ optional ShareLinkService.createGuestPlayerClaimLink
→ Claim flow later
```

### 8.4 توليد مباريات الدورة

```text
TournamentOperationsController.startGroupStage
→ TournamentLifecycleService.startGroupStage
→ GroupStageBuilder / FixtureService
→ tournamentGroups + matches
```

### 8.5 تسجيل نتيجة المباراة المستهدف

```text
ScoreSubmitScreen
→ ScoreSubmitController.submit
→ MatchSettlementService.submitScore
→ matches update
→ MatchEventService.upsertEvents(goal/mvp)
→ MatchSettlementService.approveScore or pendingReview
→ TournamentLifecycleService.refreshGroupStandings
→ StatsSnapshotService.refreshTopScorers
→ Share cards shown
```

### 8.6 Claim player

```text
Shared claim link
→ ClaimEntryScreen
→ GuestPlayerClaimController.loadClaimTarget
→ GuestClaimService.claimGuestPlayer
→ guestPlayers.linkedPlayerId = playerId
→ claimCodes.status = claimed
→ teamMemberships sync if needed
→ player profile shows previous stats
```

---

## 9. Services المستهدفة

### 9.1 موجودة يجب الحفاظ عليها

- TournamentLifecycleService
- TournamentRegistrationService
- TournamentParticipantService
- MatchSettlementService
- MatchStartService
- MatchdayService
- TeamRosterService
- GuestClaimService
- ShareLinkService
- AuditService
- DisputeService
- ShareCardCaptureService

### 9.2 جديدة مطلوبة

#### MatchEventService

مسؤول عن:

- إنشاء/تعديل/إلغاء events.
- validation: actor belongs to match side.
- validation: goals sum vs score.
- emit audit.
- expose events for UI and stats.

#### TournamentStatsService

مسؤول عن:

- بناء top scorers.
- player stats per tournament.
- team stats if not covered by group snapshots.

#### ShareCardEventTracker

مسؤول عن analytics لأحداث المشاركة.

#### PlayerIdentityResolver

مسؤول عن حل registered/guest/matchSidePlayer إلى display DTO موحد.

---

## 10. صلاحيات وأمن

### 10.1 الحالة الحالية

Firestore rules موجودة وتغطي معظم المجموعات. يوجد تحقق من owner/organizer/team manager/claim codes. لكن أي collections جديدة مثل `matchEvents` ستحتاج rules واضحة.

### 10.2 قواعد matchEvents المقترحة

- read: authenticated users على الأقل في V1.
- create/update: match organizer أو tournament organizer/assistant أو captain مصرح له حسب المرحلة.
- delete: لا حذف فعلي؛ استخدم status = voided.
- كل update يجب أن يحافظ على matchId/createdBy/createdAt.

### 10.3 قواعد shareCardEvents

- create: authenticated actor أو system client event.
- read: owner/admin فقط أو blocked حسب الحاجة.
- لا تحتوي بيانات حساسة.

---

## 11. قرارات معمارية

### ADR-001: اعتماد MatchEvent كمصدر الحقيقة للإحصائيات

**القرار:** إنشاء `matchEvents` بدل الاعتماد على player_stats فقط.  
**السبب:** دعم guest players والـ Ego والهدافين.  
**الأثر:** تعديل score submit وleaderboards والكروت.

### ADR-002: اللاعب الضيف مواطن درجة أولى

**القرار:** كل واجهة إحصائيات أو مشاركة يجب أن تقبل PlayerIdentityRef وليس Player فقط.  
**السبب:** واقع الدورات الشعبية.  
**الأثر:** تحديث UI components وservices.

### ADR-003: الكروت جزء من Core وليس Feature جانبية

**القرار:** كل lifecycle مهم ينتج CTA مشاركة.  
**السبب:** growth loop.  
**الأثر:** بناء share card registry.

### ADR-004: إيقاف Fantasy في V1

**القرار:** عدم إظهار fantasy في create tournament أو navigation.  
**السبب:** تشتيت وعدم اكتمال.  
**الأثر:** clean product surface.

---

## 12. مخاطر معمارية

| الخطر | التأثير | التخفيف |
|---|---|---|
| إضافة events بدون migration | تضارب stats القديمة والجديدة | phase migration + compatibility layer. |
| دعم guest في كل مكان يزيد التعقيد | bugs في UI/services | PlayerIdentityRef موحد. |
| Firestore indexes ناقصة | فشل queries في production | توثيق indexes وتشغيل emulator. |
| كثرة feature surfaces | تجربة مشتتة | feature gate وحذف من navigation. |
| direct writes من controllers | فقدان integrity | services فقط للعمليات الحساسة. |

---

## 13. متطلبات النشر

- release signing config بدل debug signing.
- applicationId نهائي.
- label عربي/إنجليزي مناسب.
- launcher icon نهائي.
- target SDK مطابق لمتطلبات Google Play.
- Privacy Policy + Data Safety.
- crash/error monitoring.
- closed testing.

---

## 14. خطة التطوير المعمارية المختصرة

1. **Architecture Freeze:** اعتماد Tournament Ego MVP وتحديث docs/AGENTS.
2. **MatchEvent foundation:** model/repository/service/rules/tests.
3. **Score Submit v2:** دعم الأهداف/MVP للضيوف والمسجلين.
4. **Stats snapshots:** ترتيب هدافين ولاعبين.
5. **Share Cards expansion:** Player/MVP/TopScorers/Team/Champion.
6. **UX wiring:** جعل الكروت CTAs واضحة في الرحلات.
7. **Release hardening:** signing/rules/tests/store.

---

## 15. الخلاصة

المعمارية الحالية جيدة كبداية، لكنها لا تكفي للرؤية النفسية الجديدة دون `MatchEvent` وPlayerIdentityRef وتوسيع shareables. القرار التقني الأهم قبل V1 هو تحويل المباراة من “score فقط” إلى “event-producing engine” يدعم الضيوف والمسجلين، لأن هذا هو مصدر الفخر والانتشار.
# تصميمات واجهة وتجربة المستخدم UI/UX — El7reef V1

**النسخة:** 1.0  
**التاريخ:** 2026-05-02  
**النطاق:** تجربة أول إصدار Play Store  
**الاتجاه المنتجى:** Tournament Ego MVP

---

## 1. فلسفة التجربة

تجربة الحريف يجب أن تُبنى على سؤال نفسي قبل السؤال الوظيفي:

> “هل هذه الشاشة تجعل اللاعب أو الفريق أو المنظم يشعر بالفخر والهيبة؟”

التطبيق لا يبيع تنظيمًا فقط. التنظيم هو الأساس. القيمة العاطفية هي: نجم، كارت، ترتيب، فريق، بطولة، مجد محلي.

---

## 2. مبادئ UX

1. **الدورات أولًا:** تبويب الدورات ليس feature؛ هو قلب التطبيق.
2. **الفخر في المقدمة:** الكروت والإنجازات والهدافين تظهر قبل التفاصيل الجافة.
3. **اللاعب الضيف لا يشعر بأنه ناقص:** يظهر في الكروت والهدافين قبل claim.
4. **كل رحلة لها CTA واضح:** أنشئ، أضف، سجّل، شارك، Claim.
5. **لا fake surfaces:** لا أزرار قريبًا داخل المسار الأساسي.
6. **Arabic RTL first:** النصوص والتدفق والتصميم بالعربية أولًا.
7. **WhatsApp-first sharing:** المشاركة يجب أن تكون مناسبة لجروبات واتساب وستوري.
8. **One-hand mobile:** الأفعال المهمة قرب أسفل الشاشة.

---

## 3. هيكل التنقل المقترح لـ V1

### 3.1 Bottom Navigation

1. **الرئيسية** — موجز فخر ونشاط.
2. **الدورات** — إنشاء/متابعة الدورات.
3. **المباريات** — مباريات قادمة/جارية/تحديات/وديات.
4. **فرقي** — فرق اللاعب وقوائمها.
5. **أنا** — بروفايل اللاعب وكروته.

> الكود الحالي يستخدم: الرئيسية، اكتشاف، دورات، فرقي، بروفايل. المطلوب تغيير “اكتشاف” إلى “مباريات” أو إعادة توجيهها لتكون واضحة.

### 3.2 الهرمية

```text
Home
├─ Hero: كارت اللاعب/الدورة النشطة
├─ Next Match
├─ My Ego Cards
├─ Active Tournaments
└─ Challenges

Tournaments
├─ Create Tournament
├─ Active Tournaments
├─ My Organized Tournaments
└─ Tournament Detail

Tournament Detail
├─ Overview
├─ Teams
├─ Fixtures
├─ Standings
├─ Top Scorers
├─ Highlights/Cards
└─ Organizer Ops
```

---

## 4. الشاشات الأساسية

### 4.1 Onboarding

#### الهدف

شرح الوعد النفسي بسرعة.

#### الرسائل

- “دورتك الشعبية بشكل دوري محترفين.”
- “اسمك، أهدافك، وكروتك في مكان واحد.”
- “اتضافت في دورة؟ اعمل Claim وخد مكانك.”

#### المتطلبات

- زر دخول Google واضح.
- لا شرح طويل.
- صور/كروت وهمية premium لكن لا تعد بfeatures غير موجودة.

---

### 4.2 الرئيسية Home

#### الهدف

أن يرى المستخدم سبب فتح التطبيق اليوم.

#### ترتيب المحتوى المقترح

1. **Hero Player Card Mini:** “أهلاً يا حريف” + rating/أهداف/آخر كارت.
2. **لو اللاعب داخل دورة:** مباراة قادمة أو ترتيب الهدافين.
3. **لو منظم:** CTA “كمل تشغيل دورتك”.
4. **كروت جاهزة للمشاركة:** آخر نتيجة/لاعب/MVP.
5. **تحديات ووديات:** نشاط بين الدورات.

#### Wireframe

```text
┌────────────────────────────┐
│ الحريف        صورة اللاعب  │
│ العب. اتوثق. اتفاخر.       │
├────────────────────────────┤
│ كارتك اليوم                 │
│ محمود علي | FWD | 3 أهداف  │
│ [شارك كارتك]               │
├────────────────────────────┤
│ دورتك الحالية               │
│ كأس الحي - الجولة 2         │
│ ترتيبك: 2 في الهدافين      │
├────────────────────────────┤
│ المباراة القادمة            │
│ فريق النمور × الصقور        │
│ [شوف التفاصيل]             │
└────────────────────────────┘
```

---

### 4.3 شاشة الدورات

#### الهدف

جعل الدورات هي نقطة البداية الواضحة.

#### مشاكل حالية في الكود

- Create sheet موجود، لكنه وظيفي أكثر من emotional.
- Fantasy toggle ظاهر رغم أن fantasy UI معطل.
- لا توجد كروت “دورة مشتعلة/هدافين/بطل”.

#### التصميم المقترح

- CTA رئيسي: “أنشئ دورة شعبية”.
- Subtext: “فرق، جدول، نتائج، هدافين، وكروت مشاركة.”
- Cards للدورات تعرض:
  - اسم الدورة.
  - حالة الدورة.
  - عدد الفرق.
  - آخر نتيجة أو المتصدر.
  - زر “شارك صفحة الدورة” عند توفرها.

---

### 4.4 إنشاء دورة

#### الحقول

- اسم الدورة.
- المكان.
- صورة/غلاف اختياري لاحقًا.
- حجم الفريق.
- عدد الفرق.
- نظام البطولة: مجموعات فقط / إقصاء / مجموعات ثم إقصاء.
- إعدادات التسجيل: مفتوح / بدعوة / يدوي من المنظم.

#### يجب إخفاء

- Fantasy toggle في V1.

#### UX Copy

- العنوان: “ابدأ دورتك الرسمية”.
- الوصف: “ضيف الفرق واللاعيبة حتى لو مش كلهم عندهم حساب.”
- زر: “إنشاء الدورة”.

---

### 4.5 صفحة الدورة

#### الهدف

صفحة الدورة يجب أن تشعر المستخدم أن هناك حدثًا حيًا.

#### أقسام الصفحة

1. **Hero Header:** اسم الدورة، صورة/لون، الحالة، الموقع.
2. **Story Bar:** الجولة الحالية، آخر نتيجة، المتصدر، الهداف.
3. **Quick Actions:** أضف فريق، جدول، سجل نتيجة، شارك.
4. **Tabs:** نظرة عامة، الفرق، المباريات، الترتيب، الهدافين، الكروت.
5. **Organizer Panel:** يظهر فقط للمنظم.

#### Wireframe

```text
┌────────────────────────────┐
│ كأس حي الزيتون 🏆           │
│ تسجيل مفتوح | 8 فرق         │
│ [شارك الدورة]               │
├────────────────────────────┤
│ المتصدر: الصقور             │
│ الهداف: كريم - 5 أهداف      │
├────────────────────────────┤
│ [أضف فريق] [الجدول] [نتيجة]│
├────────────────────────────┤
│ نظرة | فرق | مباريات | ترتيب│
└────────────────────────────┘
```

---

### 4.6 إدارة الفرق داخل الدورة

#### الهدف

المنظم يستطيع إدخال الواقع بسرعة.

#### حالات الفريق

- Registered Team.
- Guest Team.
- Pending Registration.
- Approved.
- Finalized.

#### UX

- زر واضح: “أضف فريق ضيف”.
- زر واضح: “شارك رابط Claim للفريق”.
- بطاقة الفريق تعرض عدد اللاعبين وحالة claim.

---

### 4.7 صفحة الفريق

#### الهدف

الفريق هو القبيلة. يجب أن يظهر ككيان له هيبة.

#### الأقسام

1. Team Hero: شعار/لون/اسم/قائد.
2. أرقام: مباريات، فوز، أهداف، بطولات.
3. قائمة اللاعبين.
4. التشكيلة.
5. نتائج وتحديات.
6. كروت الفريق.

#### CTA

- “شارك كارت الفريق”.
- “شارك التشكيلة”.
- “تحدى فريق”.
- “ادعُ لاعب”.

---

### 4.8 بروفايل اللاعب

#### الهدف

أهم شاشة نفسية للاعب.

#### التصميم المطلوب

- صورة كبيرة أو avatar محترم.
- الاسم واللقب والمركز.
- فريقه الحالي.
- أرقام فخر: أهداف، MVP، مباريات، بطولات.
- آخر كروت.
- إنجازات badges.
- “شارك كارتك”.

#### Wireframe

```text
┌────────────────────────────┐
│        صورة اللاعب          │
│ محمود علي                   │
│ المايسترو | FWD | #10       │
│ [شارك كارت اللاعب]          │
├────────────────────────────┤
│  أهداف 7 | MVP 2 | مباريات 5│
├────────────────────────────┤
│ مشارك في: كأس حي الزيتون    │
│ الترتيب: 2 في الهدافين      │
├────────────────────────────┤
│ آخر كارت: نجم المباراة      │
└────────────────────────────┘
```

#### حالة Guest قبل Claim

- “هذا بروفايل غير مؤكد.”
- “لو ده أنت، استلم بروفايلك.”
- زر: “ده أنا — Claim”.

---

### 4.9 شاشة المباراة

#### الهدف

الماتش هو الحدث الذي ينتج الفخر.

#### أقسام المباراة

- Header: الفريق A ضد B، السياق، الوقت.
- Status stepper: قبل المباراة / جارية / نتيجة / اعتماد.
- Lineups.
- Events.
- Result.
- Share CTAs.

#### أفعال أساسية

- بدء المباراة.
- سجل نتيجة.
- أضف هدف.
- اختر MVP.
- شارك النتيجة.

---

### 4.10 تسجيل النتيجة والأحداث

#### الوضع الحالي

`ScoreSubmitScreen` يدعم score في الودية، وإحصائيات للاعبين المسجلين. لكن النص يقول إن اللاعبين المؤقتين لا تُسجل لهم إحصائيات. هذا يجب تغييره.

#### التصميم المطلوب

1. Score input.
2. Goal scorers picker من كل اللاعبين: registered + guest + side players.
3. MVP picker من كل اللاعبين.
4. Validation: مجموع الأهداف لا يتجاوز النتيجة إلا بتأكيد.
5. Success sheet:
   - “النتيجة جاهزة.”
   - [شارك النتيجة]
   - [شارك MVP]
   - [شوف ترتيب الهدافين]

---

## 5. Share Cards Design System

### 5.1 المبادئ

- يجب أن تشبه كروت دوري كبير لكن بروح شعبية.
- نص قليل وواضح.
- اسم اللاعب/الفريق ضخم.
- ألوان قوية وخلفية ملعب/إضاءة.
- شعار الحريف واضح لكن لا يطغى.
- مقاس مناسب للواتساب والستوري.

### 5.2 أنواع الكروت لـ V1

#### Result Card

- أسماء الفريقين.
- النتيجة ضخمة.
- اسم الدورة أو “تحدي/ودية”.
- التاريخ.
- CTA داخلي بعد المشاركة: افتح المباراة.

#### MVP Card

- صورة/initials اللاعب.
- “نجم المباراة”.
- الفريق.
- النتيجة.
- اسم الدورة.

#### Player Card

- صورة اللاعب.
- الاسم.
- المركز.
- الفريق.
- أهداف/MVP/مباريات.
- لقب مثل “المايسترو”، “القناص”، “الحارس الأمين”.

#### Top Scorers Card

- اسم الدورة.
- Top 5 هدافين.
- صور/initials.
- عدد الأهداف.

#### Team Card

- اسم الفريق.
- الشعار/الألوان.
- القائد.
- أهم الأرقام.
- قائمة مختصرة.

#### Upcoming Match Card

- الفريقان.
- موعد ومكان.
- اسم الدورة.
- “مباراة نارية”.

#### Champion Card

- اسم البطل.
- اسم الدورة.
- صورة/شعار.
- سجل مختصر.

---

## 6. الميكروكوبي والنبرة

### 6.1 لغة التطبيق

- مصرية/عربية مفهومة، لكن ليست مبتذلة.
- حماسية، قصيرة، واضحة.
- لا تستخدم مصطلحات تقنية أمام المستخدم.

### 6.2 أمثلة

| الحالة | النص المقترح |
|---|---|
| إنشاء دورة | “ابدأ دورتك الرسمية” |
| إضافة لاعب ضيف | “ضيف لاعب حتى لو معندوش حساب” |
| Claim | “ده أنت؟ استلم بروفايلك” |
| نتيجة محفوظة | “النتيجة اتسجلت… جاهزة للمشاركة” |
| MVP | “اختار نجم الماتش” |
| Share | “شارك اللقطة” / “شارك الكارت” |
| Empty standings | “لسه مفيش نتائج. أول ماتش هيولع الجدول.” |

---

## 7. حالات فارغة وخطأ

### 7.1 لا توجد دورات

- أيقونة كأس.
- “لسه مفيش دورات.”
- “ابدأ أول دورة وخليها تتوثق.”
- زر: “أنشئ دورة”.

### 7.2 دورة بلا فرق

- “الدورة مستنية الفرق.”
- زر: “أضف فريق ضيف”.
- زر: “افتح التسجيل”.

### 7.3 مباراة بلا لاعبين

- “ضيف اللاعيبة عشان النتيجة تتحسب بأسماء.”
- زر: “أضف لاعب”.

### 7.4 لاعب ضيف غير مؤكد

- “اللاعب لسه ما استلمش بروفايله.”
- زر: “شارك رابط Claim”.

---

## 8. تحسينات على الواجهة الحالية

### 8.1 Home

- تقليل rating كعنصر رئيسي في V1 إن لم يكن مربوطًا بالدورات.
- إبراز الدورات النشطة والكروت والclaim.

### 8.2 TournamentList

- إزالة/إخفاء fantasy indication.
- إضافة “دورتي” و“دورات قريبة/جارية”.
- عرض top story بدل عدد فرق فقط.

### 8.3 TournamentOperations

- الشاشات الحالية عملية لكنها Admin-like. يجب تقسيمها:
  - Organizer Ops منفصلة للمنظم.
  - View عام جميل للاعبين.

### 8.4 ScoreSubmit

- دعم guest scorers وguest MVP.
- استبدال رسالة “اللاعبون المؤقتون لا تُسجل لهم إحصائيات” برسالة إيجابية.

### 8.5 Profile

- تحويله من صفحة بيانات إلى Player Ego Hub.
- إضافة Player Card share CTA.

---

## 9. Accessibility/Usability

- حجم خط واضح للأسماء العربية الطويلة.
- منع overflow في أسماء الفرق واللاعبين.
- دعم dark mode الحالي جيد، لكن يجب ضمان contrast في الكروت.
- كل icon button مهم يجب أن يكون معه label في المسارات الأساسية.
- الأزرار الأساسية لا تختفي في AppBar فقط.

---

## 10. Definition of Done لتجربة V1

الشاشة أو الرحلة لا تعتبر منتهية إلا إذا:

1. لها CTA واضح.
2. النص عربي مفهوم.
3. تدعم registered وguest حيث ينطبق.
4. تنتج أو تعرض لحظة فخر إن أمكن.
5. لا تحتوي زرًا ميتًا.
6. تعمل على شاشة موبايل صغيرة بدون overflow.
7. لها حالة loading/error/empty.
8. يمكن اختبارها يدويًا في سيناريو واقعي.

---

## 11. الخلاصة

UI/UX في الحريف يجب أن يتوقف عن كونه “واجهة لإدارة بيانات” ويتحول إلى “مسرح للفخر”. المنظم يرى دورته كبيرة. الفريق يرى نفسه كقبيلة. اللاعب يرى نفسه نجمًا. والكروت تجعل هذا الشعور ينتشر خارج التطبيق.
# خطة إدارة المشروع — Project Roadmap & Sprint Plan

**النسخة:** 1.0  
**التاريخ:** 2026-05-02  
**النطاق:** الوصول إلى أول إصدار عملي على Google Play  
**الاتجاه المنتجى:** Tournament Ego MVP

---

## 1. القرار الإداري

يتم تغيير اتجاه المشروع من Friendly Match MVP إلى:

> **Tournament Ego MVP**

الدورات هي القلب ومحرك الانتشار. الماتشات هي وحدة البناء. الوديات والتحديات هي عنصر العودة بين الدورات. الفخر والـ Ego هما المحرك النفسي. المشاركة هي محرك النمو.

---

## 2. واقع المشروع الحالي

### 2.1 نقاط قوة

- أساس قوي نسبيًا للبطولات والفرق والضيوف والـ claim.
- خدمات مركزية كثيرة موجودة.
- Firestore rules موجودة وليست غائبة.
- Shareables موجودة كبداية.
- Tests كثيرة في core services/repositories.
- Fantasy gated حاليًا.

### 2.2 نقاط ضعف مانعة للإطلاق

- الرؤية القديمة داخل بعض docs موجهة للوديات.
- لا يوجد MatchEvent يدعم guest players كهدافين/MVP.
- الإحصائيات الحالية تميل للاعبين المسجلين فقط.
- share cards ناقصة لأنواع الفخر الأساسية.
- بعض routes/constants غير مكتملة.
- Android release يستخدم debug signing.
- UI البطولات أقرب لأدوات تشغيل داخلية وليس منتجًا emotional للاعبين.
- Play Store readiness غير مكتملة.

---

## 3. استراتيجية الإطلاق

### 3.1 هدف V1

إطلاق نسخة تسمح بدورة حقيقية صغيرة من 4 إلى 8 فرق، بها فرق ولاعبون ضيوف ومسجلون، نتائج، هدافون، MVP، كروت، وclaim.

### 3.2 Pilot قبل Play Store العام

يفضل تنفيذ Pilot على دورة واحدة أو دورتين حقيقيتين:

- 4 أو 6 فرق.
- 5v5 أو 7v7.
- منظم واحد.
- 40–80 لاعبًا، أغلبهم يمكن أن يبدأوا كضيوف.
- قياس: عدد الكروت، claims، النتائج، feedback.

### 3.3 مبدأ التنفيذ

لا نبني feature جديدة إلا إذا خدمت واحدًا من:

- تشغيل الدورة.
- فخر اللاعب.
- كارت قابل للمشاركة.
- claim/انتشار.
- ثقة النتيجة.
- نشاط بين الدورات.

---

## 4. Roadmap عالي المستوى

```text
Phase 0: Product & Code Baseline
Phase 1: Tournament Surface Cleanup
Phase 2: Guest-first Match Events Foundation
Phase 3: Tournament Score + Leaderboards
Phase 4: Ego Share Cards
Phase 5: Player/Team Ego Profiles
Phase 6: Challenges/Friendlies Retention Loop
Phase 7: Trust, QA, and Release Hardening
Phase 8: Closed Testing + Production Submission
```

---

## 5. Sprint Plan تفصيلي

> مدة sprint المقترحة: أسبوع واحد إذا المطور واحد/صغير، أو أسبوعين لو الفريق يحتاج QA يدوي موسع.

---

## Sprint 0 — تثبيت البوصلة وتنظيف الوثائق

### الهدف

تحويل كل المستندات والتوجيهات من Friendly-first إلى Tournament Ego MVP.

### المهام

- تحديث `AGENTS.md` ليعكس الاتجاه الجديد.
- تحديث `docs/implementation_plan.md` أو إنشاء `docs/v1_tournament_ego_plan.md`.
- مراجعة feature flags.
- تحديد surface المسموح في V1.
- إنشاء checklist جديد للدورة بدل Friendly QA فقط.

### المخرجات

- وثيقة Scope نهائية.
- قائمة features مؤجلة.
- قائمة routes المسموحة.

### Acceptance Criteria

- لا يوجد مستند رئيسي يصف الودية كقلب المنتج.
- الفريق يعرف V1 بوضوح.

---

## Sprint 1 — Route & Surface Audit

### الهدف

منع التشتت والأسطح الناقصة.

### المهام

- مراجعة routes غير المسجلة: register, editProfile, playerProfile, createTeam, createTournament, leaderboard, achievements, myQrCode, activityFeed.
- قرار لكل route: register / hide / defer / implement minimal.
- إزالة fantasy toggle من CreateTournament.
- إخفاء أي social/fantasy surfaces غير ضرورية من V1.
- مراجعة Bottom Navigation labels.

### الملفات المحتملة

- `lib/app/routes/app_routes.dart`
- `lib/app/routes/app_pages.dart`
- `lib/features/home/views/home_screen.dart`
- `lib/features/tournament/views/tournament_list_screen.dart`
- `lib/core/constants/feature_flags.dart`

### Acceptance Criteria

- لا route أساسي يؤدي إلى شاشة ناقصة.
- لا fantasy exposure في دورة V1.
- navigation يعكس: Home / Tournaments / Matches / Teams / Me.

---

## Sprint 2 — Tournament UX V1

### الهدف

تحويل شاشة الدورات من قائمة إدارية إلى قلب المنتج.

### المهام

- تحسين Create Tournament sheet.
- إضافة copy يشرح دعم الفرق واللاعبين غير المسجلين.
- تحسين Tournament Card بإظهار story: عدد الفرق، الجولة، آخر نتيجة/المتصدر عند توفر البيانات.
- تحسين Tournament Detail بtabs واضحة: Overview, Teams, Fixtures, Standings, Scorers, Cards.
- فصل Organizer Ops عن view العام.

### Acceptance Criteria

- منظم جديد يستطيع إنشاء دورة وفهم الخطوات التالية.
- لاعب يفتح صفحة دورة ويفهم: الفرق، الجدول، الترتيب، الهدافين.

---

## Sprint 3 — MatchEvent Foundation

### الهدف

بناء مصدر الحقيقة للأهداف وMVP ودعم guest players.

### المهام

- إنشاء domain entity `MatchEvent`.
- إنشاء model/repository/service.
- دعم actor type: registered player, guest player, matchSidePlayer.
- إضافة Firestore collection `matchEvents`.
- إضافة rules.
- إضافة tests.
- إضافة migration compatibility من `player_stats` إن لزم.

### الملفات المحتملة

- `lib/domain/entities/match_event.dart`
- `lib/data/models/match_event_model.dart`
- `lib/domain/repositories/match_event_repository.dart`
- `lib/data/repositories/match_event_repository_impl.dart`
- `lib/core/services/match_event_service.dart`
- `firestore.rules`
- `test/core/services/match_event_service_test.dart`

### Acceptance Criteria

- يمكن تسجيل goal/MVP للاعب مسجل أو ضيف في test.
- لا يمكن تسجيل event للاعب خارج المباراة.
- void بدل delete.

---

## Sprint 4 — Score Submit v2

### الهدف

جعل تسجيل النتيجة ينتج بيانات فخر حقيقية.

### المهام

- تعديل `ScoreSubmitController` لتحميل كل لاعبي الطرفين: registered + guest/matchSidePlayers.
- بناء unified participant picker.
- إدخال score ثم goal scorers.
- اختيار MVP من كل المشاركين.
- validation: أهداف الفريق مقابل score.
- ربط MatchSettlementService بـ MatchEventService.
- success sheet تعرض share CTAs.

### الملفات المحتملة

- `lib/features/match/controllers/score_submit_controller.dart`
- `lib/features/match/views/score_submit_screen.dart`
- `lib/core/services/match_settlement_service.dart`
- `lib/core/services/official_match_roster_service.dart`
- `lib/features/match/models/...`

### Acceptance Criteria

- لاعب ضيف يستطيع أن يظهر كهداف.
- لاعب ضيف يستطيع أن يكون MVP.
- النتيجة تحفظ وتولد events.
- لا تظهر رسالة “اللاعبون المؤقتون لا تُسجل لهم إحصائيات”.

---

## Sprint 5 — Tournament Leaderboards

### الهدف

إنتاج ترتيب وهدافين حقيقيين للدورة.

### المهام

- بناء TournamentStatsService.
- حساب top scorers من matchEvents.
- عرض Scorers tab في Tournament Detail.
- تحديث standings بعد approve score.
- بناء empty states.

### Acceptance Criteria

- بعد تسجيل نتيجة بها أهداف، يظهر الهدافون في صفحة الدورة.
- guest scorer يظهر باسمه وحالة claim.
- يمكن مشاركة كارت هدافين.

---

## Sprint 6 — Ego Share Cards Pack 1

### الهدف

تحويل البيانات إلى انتشار.

### المهام

- تصميم/تنفيذ MVP Card.
- تصميم/تنفيذ Player Card.
- تصميم/تنفيذ Top Scorers Card.
- تحسين Result Card ليظهر اسم الدورة وMVP.
- إضافة CTAs بعد score submit.
- تتبع share events analytics.

### الملفات المحتملة

- `lib/features/shareables/widgets/*`
- `lib/features/shareables/controllers/*`
- `lib/features/shareables/models/*`
- `lib/features/shareables/services/share_card_capture_service.dart`

### Acceptance Criteria

- كل كارت يعمل capture/share.
- الكارت واضح عربيًا ولا يحدث overflow في أسماء طويلة.
- يمكن مشاركته بعد نتيجة المباراة مباشرة.

---

## Sprint 7 — Player Claim & Ego Profile

### الهدف

جعل اللاعب يجد نفسه ويستلم بروفايله.

### المهام

- تحسين GuestPlayerClaim screen copy/UX.
- بعد claim، توجيه المستخدم إلى Player Profile.
- عرض إحصائيات اللاعب من guest history.
- إضافة Player Card CTA.
- إضافة حالة “غير مؤكد” لبروفايل guest.

### الملفات المحتملة

- `lib/features/guest_claim/*`
- `lib/features/profile/*`
- `lib/core/services/guest_claim_service.dart`
- `lib/core/services/share_link_service.dart`

### Acceptance Criteria

- لاعب ضيف يستطيع claim من رابط.
- بعد claim يرى أهدافه السابقة.
- يستطيع مشاركة كارت اللاعب.

---

## Sprint 8 — Team Ego & Challenges

### الهدف

تقوية القبيلة والعودة بين الدورات.

### المهام

- تحسين Team Profile/Team Roster كصفحة هوية.
- Team Card.
- Team lineup share CTA.
- تحدي فريق لفريق.
- ربط challenge match بنفس score/event/share loop.

### Acceptance Criteria

- فريق يشارك كارت فريق.
- فريق ينشئ تحديًا.
- نتيجة التحدي تنتج كارت وتظهر في سجل الفريق.

---

## Sprint 9 — Trust, Audit, Disputes UX

### الهدف

حماية الفخر من الخناقات.

### المهام

- ربط audit events بتعديل النتيجة/events.
- إضافة “طلب تصحيح” للاعب على goal/MVP.
- Dispute flow بسيط للمنظم.
- عرض حالة النتيجة بوضوح.

### Acceptance Criteria

- يمكن فتح dispute على نتيجة/إحصائية.
- المنظم يرى dispute ويقرر.
- audit يظهر من فعل ماذا ومتى.

---

## Sprint 10 — Release Hardening

### الهدف

تجهيز Play Store.

### المهام

- `flutter pub get`.
- `dart analyze lib/`.
- `flutter test`.
- مراجعة failing tests إن وجدت.
- إنشاء release keystore.
- تعديل `android/app/build.gradle.kts` release signing.
- ضبط versionCode/versionName.
- ضبط app label إلى “الحريف” أو “El7reef”.
- مراجعة permissions.
- تحديث target SDK حسب متطلبات Google Play.
- إعداد Privacy Policy وData Safety.
- إعداد screenshots وfeature graphic.

### Acceptance Criteria

- app-release.aab موقّع release.
- لا debug signing.
- لا permissions غير مبررة.
- build يثبت على جهاز اختبار.

---

## Sprint 11 — Closed Testing & Pilot

### الهدف

اختبار واقعي قبل production.

### المهام

- إنشاء closed testing track.
- دعوة 12 tester على الأقل إذا الحساب الشخصي جديد.
- تشغيل Pilot بدورة حقيقية صغيرة.
- جمع feedback عبر checklist.
- إصلاح blockers.
- تقديم production access عند تحقق الشروط.

### Acceptance Criteria

- 12 tester opted-in لمدة 14 يومًا متصلة إذا كان الحساب يتطلب ذلك.
- تسجيل 3–5 مباريات حقيقية على الأقل.
- مشاركة 10+ كروت.
- claim ناجح للاعبين ضيوف.

---

## 6. QA Plan

### 6.1 سيناريوهات إجبارية

1. دورة 4 فرق، فرق ضيوف فقط.
2. دورة مختلطة: فريق مسجل + فريق ضيف.
3. لاعب ضيف يسجل هدفًا ثم يعمل claim.
4. MVP لاعب ضيف ثم claim.
5. ترتيب هدافين بعد 3 مباريات.
6. مشاركة كارت نتيجة ومVP وهدافين.
7. اعتراض على هدف ثم حل الاعتراض.
8. تحدي بين فريقين خارج الدورة.
9. ودي بلا دورة مع لاعبين ضيوف.

### 6.2 اختبارات تقنية

- Repositories serialization/deserialization.
- Services validations.
- Firestore rules emulator.
- Widget tests للكروت المهمة.
- Manual QA على Android device.

---

## 7. Release Gates

### Product Gate

- الدورة تعمل من البداية حتى أول leaderboard.
- اللاعب الضيف ليس ناقصًا في الفخر.
- الكروت مغرية وواضحة.
- لا fake features في المسار الأساسي.

### Engineering Gate

- Analyze clean.
- Core tests pass.
- Firestore rules tested.
- Release signing done.
- No critical crash في pilot.

### Store Gate

- Target SDK compliant.
- Privacy Policy جاهزة.
- Data Safety صحيح.
- Closed testing completed إذا مطلوب.
- Screenshots من flow الحقيقي.

---

## 8. المخاطر وخطة التخفيف

| الخطر | الاحتمال | التأثير | التخفيف |
|---|---:|---:|---|
| MatchEvent refactor يأخذ وقتًا | متوسط | عالي | تنفيذه مبكرًا كسبرنت مستقل. |
| UX البطولات معقد للمنظم | متوسط | عالي | wizard + checklists + defaults. |
| كروت غير جذابة | متوسط | عالي | اختبارها بصريًا مع لاعبين حقيقيين. |
| Claim abuse | متوسط | متوسط | expiry + approval + audit. |
| Google Play readiness يتأخر | متوسط | عالي | Sprint منفصل للrelease. |
| Firebase تكلفة الصور | منخفض/متوسط | متوسط | ضغط الصور وتأجيل media-heavy. |

---

## 9. ترتيب الأولويات الدائم

1. دورة تعمل.
2. لاعب يظهر ويفتخر.
3. ضيف يستطيع claim.
4. نتيجة تولد أحداث وإحصائيات.
5. كارت ينتشر.
6. ثقة واعتماد.
7. تحديات/وديات للعودة.
8. أي شيء آخر.

---

## 10. أول 10 مهام تنفيذية مباشرة

1. تحديث docs وAGENTS إلى Tournament Ego MVP.
2. إزالة fantasy toggle من CreateTournament.
3. حسم routes غير المسجلة/غير المستخدمة.
4. تصميم MatchEvent model/service/repository/rules.
5. تعديل ScoreSubmit ليعرض guest + registered participants.
6. بناء TopScorers service/snapshot.
7. بناء MVP Card.
8. بناء Player Card.
9. تحسين Guest Claim بعد الكارت.
10. إصلاح Android release signing.

---

## 11. الخلاصة

الطريق إلى Play Store ليس إضافة features كثيرة. الطريق هو إثبات حلقة واحدة قوية:

> دورة → ماتش → أحداث → ترتيب/هدافين → كارت → مشاركة → Claim → عودة.

لو الحلقة دي اشتغلت في دورة شعبية حقيقية، الحريف لديه منتج قابل للنمو. لو لم تعمل، أي إضافة أخرى ستكون تزيينًا فوق أساس غير مكتمل.
