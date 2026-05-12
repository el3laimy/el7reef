# تقرير مراجعة الباكيند واتصال Firebase

**تاريخ المراجعة:** 2026-05-08  
**النطاق:** طبقة الخدمات، الريبوزيتوري، قواعد Firestore، إعدادات Firebase  
**الحالة:** مراجعة فقط — لم يتم تعديل أي كود

---

## ملخص تنفيذي

الباكيند مبني بشكل جيد مع فصل واضح بين الطبقات (Clean Architecture): Domain → Data → Services → Controllers. اتصال Firebase مستقر ومتسق. ومع ذلك، هناك **عدة مشاكل أمنية وثغرات في الاتصال** تحتاج معالجة قبل الإصدار.

### تقييم عام

| المجال | التقييم | الملاحظة |
|--------|---------|----------|
| هيكلة الكود | ✅ جيد | Clean Architecture واضح |
| قواعد Firestore | ⚠️ متوسط | تغطية جيدة مع ثغرات محددة |
| أمن المصادقة | ⚠️ متوسط | نقاط ضعف موجودة |
| اتساق الاتصال | ⚠️ متوسط | بعض عدم الاتساق |
| معالجة الأخطاء | ❌ ضعيف | غياب شبه كامل في الريبوزيتوري |
| حماية البيانات | ⚠️ متوسط | مفاتيح API مكشوفة |

---

## 🔴 مشاكل أمنية حرجة (P0)

### 1. مفاتيح Firebase API مكشوفة في الكود المصدري

**الملف:** `lib/firebase_options.dart`

```dart
static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCG0kojRrJ4WCFfaFsFAMpcE_mGPbZ4JXs',  // ← مكشوف
    appId: '1:807857485912:android:4105280c0a74c585d8f22d',
    ...
);
```

**الخطر:** هذا الملف يُولد تلقائياً بواسطة FlutterFire CLI وهو مصمم ليكون في الكود. لكن يجب:
- التأكد من تفعيل **App Check** لمنع الاستخدام غير المصرح به
- تفعيل **API key restrictions** في Google Cloud Console
- التأكد من أن `google-services.json` في `.gitignore`

**التوصية:** تفعيل Firebase App Check في الإنتاج. تقييد API keys لتطبيقات Android/iOS المحددة فقط.

---

### 2. خمس مجموعات Firestore بدون قواعد أمنية

**المشكلة:** الكود يكتب ويقرأ من مجموعات **غير مغطاة** بقواعد أمنية في `firestore.rules`:

| المجموعة | مستخدمة في | الحالة في Rules |
|----------|-----------|----------------|
| `challenges` | `ChallengeRepositoryImpl` — create, read, update | ❌ غير موجودة |
| `matchInvitations` | `MatchInvitationRepositoryImpl` — create, read, update | ❌ غير موجودة |
| `friendRequests` | `FirebasePaths` (معرّفة) | ❌ غير موجودة |
| `achievements` | `FirebasePaths` (معرّفة) | ❌ غير موجودة |
| `notifications` | `FirebasePaths` (معرّفة) | ❌ غير موجودة |

**الخطر:** يوجد catch-all rule في نهاية الملف:
```
match /{document=**} {
    allow read, write: if false;
}
```
هذا يعني أن هذه المجموعات **محظورة تماماً** — أي محاولة كتابة أو قراءة ستفشل في الإنتاج.

**التأثير:**
- `challenges` و `matchInvitations` مستخدمة فعلياً بريبوزيتوري كامل → **ستفشل في الإنتاج**
- الريبوزيتوري لا يتعامل مع أخطاء Firestore → التطبيق سيكرش

**التوصية:** إضافة قواعد أمنية لـ `challenges` و `matchInvitations` كحد أدنى.

---

### 3. `analyticsEvents` — إنشاء بدون مصادقة

**الملف:** `firestore.rules` سطر 1140-1162

```
match /analyticsEvents/{eventId} {
    allow create: if request.resource.data.keys().hasOnly([...]) &&
        ...
        (!request.resource.data.keys().hasAny(['actorId']) ||
            (request.resource.data.actorId is string &&
             isAuthenticated() && ...));
```

**المشكلة:** فحص `isAuthenticated()` داخل شرط `actorId` الاختياري. إذا لم يُرسل `actorId`، يمكن لمستخدم غير مسجل إنشاء analytics events.

**الخطر:** متوسط — يمكن لأي شخص بدون حساب ملء مجموعة `analyticsEvents` ببيانات وهمية (Firestore billing attack).

**التوصية:** إضافة `isAuthenticated()` كشرط أساسي لـ create.

---

### 4. `organizerActions` — أي مستخدم مسجل يمكنه الإنشاء

```
match /organizerActions/{actionId} {
    allow create: if isAuthenticated();
```

**المشكلة:** لا يوجد أي تحقق من أن المستخدم هو فعلاً organizer. أي مستخدم مسجل يمكنه إنشاء `organizerAction`.

**الخطر:** متوسط — يمكن لأي لاعب انتحال صفة المنظم في سجلات الإجراءات.

**التوصية:** إضافة تحقق من `request.resource.data.actorId == request.auth.uid` ومن ملكية الكيان المرتبط.

---

### 5. `reservedUsernames` — ثغرة في تحديث الملكية

```
match /reservedUsernames/{username} {
    allow create, update: if isAuthenticated() && (
        request.resource.data.ownerId == request.auth.uid ||
        request.resource.data.previousOwnerId == request.auth.uid
    );
```

**المشكلة:** يمكن لمستخدم أن يُحدّث username محجوز بوضع `previousOwnerId` على uid الخاص به — حتى لو لم يكن هو المالك الأصلي.

**الخطر:** عالي — يمكن لأي مستخدم سرقة أسماء مستخدمين محجوزة.

**التوصية:** إضافة تحقق من أن `resource.data.ownerId == request.auth.uid` (المالك الحالي) قبل السماح بالتحديث.

---

## 🟡 مشاكل في الاتصال والاتساق (P1)

### 6. `firebase_options.dart` موجود لكن غير مستخدم

**الملف:** `lib/main.dart`

```dart
// تم حذف سطر استدعاء firebase_options.dart القديم
...
await Firebase.initializeApp(); // سطر واحد فقط نظيف
```

**المشكلة:** `Firebase.initializeApp()` بدون تمرير `options` يعتمد على `google-services.json` (Android) أو `GoogleService-Info.plist` (iOS). ملف `firebase_options.dart` موجود لكنه ملف ميت.

**التأثير:** يعمل على Android بسبب `google-services.json`، لكن:
- الملف الميت يُسبب ارتباك
- إذا احتجت دعم Web أو Desktop مستقبلاً ستحتاج إعادة الربط

**التوصية:** إما استخدام `DefaultFirebaseOptions.currentPlatform` أو حذف الملف.

---

### 7. غياب معالجة الأخطاء في طبقة الريبوزيتوري

**المشكلة:** جميع الـ Repository Implementations (30 ملف) لا تحتوي على **أي** `try-catch` أو `catchError`. كل عمليات Firestore تُلقى مباشرة للـ caller.

**أمثلة:**

```dart
// challenge_repository_impl.dart
Future<void> createChallenge(Challenge challenge) async {
    await _challengesRef.doc(challenge.id).set(model.toJson());
    // لا يوجد catch لأخطاء الشبكة أو الصلاحيات
}
```

**الخطر:**
- أخطاء الشبكة (offline) تصل للـ UI بدون رسالة مفهومة
- أخطاء الصلاحيات (permission-denied) تظهر كـ Firebase exception خام
- لا يوجد retry logic لأي عملية

**التوصية:** إضافة طبقة error handling مركزية تترجم Firebase exceptions لأخطاء domain واضحة.

---

### 8. `ChallengeRepositoryImpl` و `MatchInvitationRepositoryImpl` — Firestore instance غير injectable

```dart
class ChallengeRepositoryImpl implements ChallengeRepository {
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;  // ← hardcoded
```

**المشكلة:** على عكس باقي الريبوزيتوري التي تقبل `FirebaseFirestore?` كـ parameter، هذان الملفان يستخدمان `FirebaseFirestore.instance` مباشرة.

**التأثير:** لا يمكن اختبارها بـ mock Firestore — غير قابلة للـ unit testing.

**التوصية:** تحويلها لنفس النمط:
```dart
ChallengeRepositoryImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;
```

---

### 9. عمليات متعددة بدون Transaction

**الملف:** `player_repository_impl.dart` — `submitMatchResult()`

```dart
final batch = _firestore.batch();
batch.update(playerDoc, updates);
batch.set(statsDoc, statModel.toJson());
await batch.commit();
```

**المشكلة:** يستخدم `batch` بدلاً من `transaction`. الـ batch لا يضمن أن البيانات لم تتغير بين القراءة والكتابة (no read-before-write guarantee).

**مقارنة:** `MatchSettlementService` و `GuestClaimService` يستخدمان `runTransaction` بشكل صحيح.

**التوصية:** تحويل العمليات الحساسة من batch إلى transaction حيث يوجد read-then-write pattern.

---

### 10. عدم اتساق في تسمية Firestore instance

| النمط | المستخدم في |
|-------|-----------|
| `_firestore` | أغلب الريبوزيتوري |
| `_db` | `MatchRepositoryImpl`, `AuditRepositoryImpl`, `DisputeRepositoryImpl`, `FantasyRepositoryImpl`, `UsernameService` |

**التأثير:** يُصعّب القراءة والصيانة لكنه ليس bug.

---

## 🟡 مشاكل أمنية في طبقة الخدمات (P1)

### 11. عدم اتساق فحص الصلاحيات بين Service Layer و Firestore Rules

**المشكلة:** `TournamentPermissionService` يدعم أدوار المساعدين (assistant roles) لكن `firestore.rules` تتحقق من `organizerId` فقط.

| العملية | Service Layer | Firestore Rules |
|---------|--------------|-----------------|
| تعديل نتائج | organizer + full + resultsOnly + emergency | organizer فقط |
| إدارة الفرق | organizer + full + emergency | organizer فقط |
| بدء المباراة | organizer فقط | organizer فقط |

**الخطر:** إذا تم تفعيل المساعدين في الـ service layer، ستفشل عمليات الكتابة عند Firestore rules لأنها لا تعرف المساعدين.

**الوضع الحالي:** آمن لأن كلاهما يحظر غير المنظم. لكن عند تفعيل المساعدين ستكون هناك مشكلة.

**التوصية:** توثيق أن Firestore rules يجب تحديثها عند تفعيل assistant permissions.

---

### 12. `MatchStartService` — يمنع بدء مباريات البطولة

```dart
if (match.tournamentId != null && match.tournamentId!.isNotEmpty) {
    reasons.add('مباريات البطولة تبدأ من إدارة البطولة/الفيكستشر فقط.');
}
```

**الملاحظة:** هذا تصميم مقصود وليس bug — يحمي من بدء المباراة خارج tournament lifecycle. ✅

---

## 🟢 نقاط قوة

### 13. أمان قوي في Claim Flow

- Claim codes تتحقق من proof-of-possession عبر document ID
- `canSelfClaimGuestPlayer` يحمي كل field من التعديل
- `canFinalizeGuestPlayerClaimCode` يتحقق من expiry وstatus
- `GuestClaimService` يستخدم pre-flight conflict detection + transaction
- Idempotent claim design (same player claiming twice = safe)

### 14. حماية جيدة للبيانات الحساسة

- `claimCodes` — `list` محدود لـ creator فقط، `get` يحتاج authentication
- `disputes` — الـ raisedBy وmatchId لا يمكن تغييرهم بعد الإنشاء
- `auditEvents` — append-only (no update, no delete)
- `matchEvents` — void-only updates (can't change data, only mark voided)

### 15. Catch-All Rule يحمي المجموعات غير المعروفة

```
match /{document=**} {
    allow read, write: if false;
}
```

### 16. اتساق في استخدام `FirebasePaths`

كل الريبوزيتوري (ما عدا `player_stats` subcollection) تستخدم `FirebasePaths` constants — لا يوجد hardcoded collection names.

### 17. Session Reset Coordinator

تصميم ذكي لحماية بيانات الجلسة:
- ينظف state عند تغيير المستخدم
- يمنع تسرب بيانات مستخدم لمستخدم آخر
- يدعم callbacks مسجلة لكل feature

---

## 📊 جدول ملخص المشاكل

| # | المشكلة | الخطورة | الأولوية |
|---|---------|---------|----------|
| 1 | API keys مكشوفة بدون App Check | عالي | P0 |
| 2 | 5 مجموعات بدون Firestore rules (challenges/invitations ستفشل) | حرج | P0 |
| 3 | `analyticsEvents` create بدون auth | متوسط | P0 |
| 4 | `organizerActions` بدون تحقق من الهوية | متوسط | P1 |
| 5 | `reservedUsernames` ثغرة سرقة الاسم | عالي | P0 |
| 6 | `firebase_options.dart` ملف ميت | منخفض | P2 |
| 7 | غياب error handling في الريبوزيتوري | عالي | P1 |
| 8 | Firestore instance غير injectable في 2 repos | منخفض | P2 |
| 9 | batch بدلاً من transaction | متوسط | P1 |
| 10 | عدم اتساق تسمية | منخفض | P3 |
| 11 | عدم اتساق service vs rules permissions | متوسط | P1 |

---

## التوصيات ذات الأولوية القصوى

1. **فوري:** إضافة Firestore rules لـ `challenges` و `matchInvitations` — بدونها ستفشل هذه الميزات في الإنتاج
2. **فوري:** إصلاح ثغرة `reservedUsernames` — يمكن لأي مستخدم سرقة أسماء مستخدمين
3. **فوري:** إضافة `isAuthenticated()` كشرط أساسي لـ `analyticsEvents` create
4. **قبل الإصدار:** تفعيل Firebase App Check
5. **قبل الإصدار:** إضافة طبقة error handling مركزية للريبوزيتوري
6. **بعد الإصدار:** توحيد injection pattern لـ Firestore instance
