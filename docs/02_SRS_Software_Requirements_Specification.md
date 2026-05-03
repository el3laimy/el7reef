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
