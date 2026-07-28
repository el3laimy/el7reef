# El7reef Role & Permission Matrix — Draft 0

**Status:** `REFERENCE — NOT AN ACTIVE PLAN`&rlm;. Current security work and ticket status live in `docs/core/00_Master_Product_Development_Plan.md`&rlm;.

## 0. الهدف من الوثيقة

هذه الوثيقة تحدد من يملك ماذا، ومن يرى ماذا، ومن ينفذ ماذا داخل تطبيق الحريف.

الهدف ليس وصف UI فقط، بل وضع قاعدة واحدة يجب أن يلتزم بها:

1. UI visibility.
2. Controller/service guards.
3. Firestore rules أو backend trusted checks.
4. Tests، خصوصًا بحسابين مختلفين.

أي Action حساس غير موجود هنا لا يجب تنفيذه قبل إضافته لهذه الوثيقة.

---

## 1. المبادئ الحاكمة

### 1.1 الرؤية لا تعني الإدارة

المستخدم قد يرى بطولة أو فريقًا أو مباراة، لكن هذا لا يمنحه أي صلاحية تعديل.

### 1.2 الدور دائمًا محدد بسياق

لا يوجد مستخدم “منظم” بشكل عام. هو منظم لبطولة معينة فقط.

لا يوجد مستخدم “قائد” بشكل عام. هو قائد لفريق معين فقط.

### 1.3 UI guard ليس أمانًا

إخفاء الزر لا يكفي. كل action حساس يجب أن يُمنع أيضًا في controller/service وFirestore rules.

### 1.4 أقل صلاحية ممكنة

أي دور يحصل فقط على الصلاحية الضرورية له. لا نستخدم canManage عام إلا لو محدد بسياق واضح.

---

## 2. الأدوار الأساسية

## 2.1 Anonymous

مستخدم غير مسجل.

صلاحياته:

- يرى landing/onboarding فقط.
- لا يقرأ بيانات حساسة.
- لا ينشئ أو يعدل.
- لا يفتح claim إلا بعد login أو register مع حفظ الرابط إن أمكن.

## 2.2 Registered Player

لاعب لديه حساب.

صلاحياته:

- تعديل ملفه الشخصي.
- رؤية public profiles.
- رؤية public tournaments حسب visibility.
- قبول/رفض دعوات مستقبلية.
- claim guest identity عبر token صالح.

لا يحق له:

- إدارة بطولة لم ينشئها.
- إدارة فريق ليس له دور إداري فيه.
- تعديل نتائج أو جداول إلا لو له دور محدد.

## 2.3 Guest Player

لاعب مؤقت بدون حساب.

صلاحياته داخل التطبيق قبل claim:

- لا يملك جلسة مستقلة.
- يظهر في roster/events/profile.
- يتم claim عبر token فقط.

لا يحق له:

- تسجيل دخول كضيف.
- تعديل بياناته بنفسه.
- إدارة فريق أو بطولة.

## 2.4 Team Owner / Captain

مدير فريق معين.

صلاحياته داخل هذا الفريق فقط:

- تعديل بيانات الفريق الأساسية.
- إدارة roster.
- إضافة guest players.
- إرسال claim links لضيوف فريقه.
- تقديم الفريق لبطولة.
- سحب الفريق من بطولة قبل القفل حسب rules.
- ربما إرسال نتيجة لفريقه إذا نظام النتائج يسمح.

لا يحق له:

- تعديل البطولة.
- قبول فرق أخرى.
- توليد fixtures للبطولة.
- اعتماد نتائج كمنظم.

## 2.5 Vice Captain

دور مساعد داخل فريق معين.

V1 Decision:

- إذا كان موجودًا في الكود ويستخدم، يجب تحديد صلاحياته بدقة.
- إذا غير واضح، يعامل كـ player عادي في V1 أو يمنح صلاحيات roster محدودة فقط.

صلاحيات محتملة:

- إضافة/دعوة لاعبين إذا captain فوّضه.
- إرسال guest claim link إذا كان مسموحًا.
- submit score لفريقه إذا سمح النظام.

لا يحق له افتراضيًا:

- حذف الفريق.
- تغيير owner/captain.
- إدارة بطولة.

## 2.6 Tournament Organizer

منظم بطولة معينة.

صلاحياته داخل هذه البطولة فقط:

- تعديل بيانات البطولة.
- فتح/غلق التسجيل.
- قبول/رفض الفرق.
- توليد/تعديل fixtures.
- تحديد مواعيد المباريات.
- اعتماد النتائج.
- حل النزاعات.
- إغلاق/إلغاء البطولة.

لا يحق له:

- إدارة فرق ليست ملكه خارج سياق البطولة.
- تعديل بيانات لاعب أو فريق مباشرة إلا من خلال registration/approval flows.

## 2.7 Match Official / Referee

مؤجل غالبًا إلى V1.1.

لو دخل لاحقًا:

- يدير مباراة محددة فقط.
- لا يدير البطولة كلها.
- لا يملك صلاحيات organizer العامة.

## 2.8 Viewer

مستخدم مسجل أو غير مسجل يرى public surfaces.

صلاحياته:

- read-only.
- لا أزرار إدارة.
- لا mutations.

---

## 3. Tournament Permissions

### 3.1 Tournament visibility

| Action | Anonymous | Registered | Player in tournament | Team Captain | Organizer |
|---|---:|---:|---:|---:|---:|
| View public tournament | ربما | نعم | نعم | نعم | نعم |
| View private/invite-only tournament | لا | حسب دعوة/عضوية | نعم | نعم | نعم |
| View tournament standings | حسب visibility | حسب visibility | نعم | نعم | نعم |
| View tournament fixtures | حسب visibility | حسب visibility | نعم | نعم | نعم |
| View organizer operations | لا | لا | لا | لا | نعم فقط |

### 3.2 Tournament management

| Action | Organizer | Team Captain | Player | Viewer |
|---|---:|---:|---:|---:|
| Create tournament | نعم | ربما كـ registered user | لا/نعم حسب product | لا |
| Edit tournament name/details | نعم | لا | لا | لا |
| Change visibility | نعم | لا | لا | لا |
| Change format | نعم قبل start فقط | لا | لا | لا |
| Open registration | نعم | لا | لا | لا |
| Close registration | نعم | لا | لا | لا |
| Cancel tournament | نعم | لا | لا | لا |
| Archive tournament | نعم/النظام | لا | لا | لا |

### 3.3 Tournament team registration

| Action | Organizer | Team Captain | Vice Captain | Player | Viewer |
|---|---:|---:|---:|---:|---:|
| Submit team to tournament | لا إلا لو يقود فريقًا | نعم لفريقه | ربما | لا | لا |
| Withdraw submitted team | لا إلا override | نعم لفريقه قبل القفل | ربما | لا | لا |
| Approve team | نعم | لا | لا | لا | لا |
| Reject team | نعم | لا | لا | لا | لا |
| Disqualify team | نعم مع audit | لا | لا | لا | لا |
| View approved teams | حسب visibility | نعم | نعم | نعم | نعم/حسب visibility |

### 3.4 Tournament fixtures and schedule

| Action | Organizer | Team Captain | Player | Viewer |
|---|---:|---:|---:|---:|
| Generate fixture pairings | نعم | لا | لا | لا |
| Create manual match | نعم | لا | لا | لا |
| Assign scheduledAt | نعم | لا | لا | لا |
| Assign venue/court | نعم | لا | لا | لا |
| Publish fixtures | نعم | لا | لا | لا |
| Request reschedule | ربما نيابة عن بطولة | نعم لفريقه لاحقًا | لا | لا |
| Approve reschedule | نعم | لا | لا | لا |
| Cancel/postpone match | نعم | لا | لا | لا |

V1 Decision:

- Reschedule request من team captain يؤجل إذا غير موجود.
- Organizer-only rescheduling يكفي V1.

---

## 4. Team Permissions

### 4.1 Team visibility

| Action | Owner/Captain | Team Player | Other Registered | Viewer |
|---|---:|---:|---:|---:|
| View own team | نعم | نعم | حسب visibility | حسب visibility |
| View roster | نعم | نعم | حسب privacy | لا/حسب privacy |
| View guest players | نعم | نعم/محدود | حسب privacy | لا |
| View phone/private info | لا افتراضيًا | لا | لا | لا |

### 4.2 Team management

| Action | Owner | Captain | Vice Captain | Player | Viewer |
|---|---:|---:|---:|---:|---:|
| Edit team info | نعم | نعم حسب التصميم | لا/محدود | لا | لا |
| Delete/archive team | نعم | لا أو نعم بتأكيد | لا | لا | لا |
| Invite registered player | نعم | نعم | ربما | لا | لا |
| Add guest player | نعم | نعم | ربما | لا | لا |
| Remove player | نعم | نعم | ربما | لا | لا |
| Promote vice captain | نعم | ربما | لا | لا | لا |
| Change owner | نعم فقط | لا | لا | لا | لا |
| Resend guest claim link | نعم | نعم | ربما | لا | لا |

### 4.3 Team membership lifecycle permissions

| Action | Owner/Captain | Invited Player | Existing Player | Viewer |
|---|---:|---:|---:|---:|
| Send invite | نعم | لا | لا | لا |
| Accept invite | لا | نعم | لا | لا |
| Decline invite | لا | نعم | لا | لا |
| Revoke invite | نعم | لا | لا | لا |
| Leave team | لا | لا | نعم | لا |
| Remove member | نعم | لا | لا | لا |

---

## 5. Match and Score Permissions

### 5.1 Match visibility

| Action | Organizer | Team Captain | Player in match | Other viewer |
|---|---:|---:|---:|---:|
| View scheduled match | نعم | نعم | نعم | حسب tournament visibility |
| View lineup/result | نعم | نعم | نعم | حسب visibility |
| View admin score controls | نعم | حسب design | لا | لا |

### 5.2 Result flow — V1 proposed

V1 recommended minimal flow:

```text
score submitted
→ organizer reviews
→ approved/locked
```

### 5.3 Score actions

| Action | Organizer | Team Captain | Player | Viewer |
|---|---:|---:|---:|---:|
| Submit score | نعم أو captain حسب final design | ربما لفريقه | لا | لا |
| Edit submitted score | نعم قبل approval | ربما قبل approval | لا | لا |
| Approve score | نعم | لا | لا | لا |
| Dispute score | نعم/resolve | نعم لفريقه | ربما | لا |
| Lock score | نعم | لا | لا | لا |
| Void/rollback result | نعم مع audit | لا | لا | لا |

Decision needed:

- هل captain يسمح له submit score في V1؟
- إن نعم، هل يحتاج organizer approval؟ غالبًا نعم.

---

## 6. MatchEvent Permissions

| Action | Organizer | Score submitter | Player | Viewer |
|---|---:|---:|---:|---:|
| Record goal event | ضمن score flow | ضمن score flow | لا | لا |
| Record MVP event | ضمن score flow | ضمن score flow | لا | لا |
| Void MatchEvent | نعم أو creator قبل approval | لا بعد approval | لا | لا |
| Read MatchEvents | حسب match/tournament visibility | نعم | نعم | حسب visibility |

Important:

- MatchEvents لا يجب أن تكون قابلة للعبث بعد اعتماد النتيجة.
- إذا تم تعديل score approved، يجب audit وreconciliation.

---

## 7. Guest Claim Permissions

### 7.1 Claim link creation/resend

| Action | Team Owner/Captain | Tournament Organizer | Player | Viewer |
|---|---:|---:|---:|---:|
| Create guest claim link for team guest | نعم لفريقه | نعم إذا guest داخل بطولته وبصلاحية واضحة | لا | لا |
| Resend guest claim link | نعم لفريقه | نعم حسب surface | لا | لا |
| View raw claimCode | لا | لا | لا | لا |
| Query claimCodes broadly | لا | لا | لا | لا |

### 7.2 Claim execution

| Action | Token holder authenticated user | Other user |
|---|---:|---:|
| Open exact claim route with code | نعم | لا بدون code |
| Claim guest profile | نعم إذا service/rules validate | لا |
| Claim from public profile without token | لا | لا |

---

## 8. Public Profile Permissions

| Action | Profile Owner | Guest Token Holder | Viewer |
|---|---:|---:|---:|
| View public stats | نعم | نعم | حسب visibility |
| Edit registered profile | نعم | لا | لا |
| Claim guest profile | لا إلا إذا token holder | نعم مع token | لا |
| See raw claimCode | لا | لا | لا |
| Open guest claim CTA without token | لا | لا | لا |

---

## 9. Search / Invite / Friends Permissions

V1 Decision:

- Full friends خارج V1.
- Player search قد يدخل فقط لدعوة الفريق إذا كان role model جاهز.

### 9.1 If player search enters V1

| Action | Registered Player | Team Captain | Viewer |
|---|---:|---:|---:|
| Search public player handle/name | نعم حسب privacy | نعم | لا/ربما |
| Invite player to team | لا إلا لو captain | نعم لفريقه | لا |
| See private phone/email | لا | لا | لا |

### 9.2 Friend requests

V1: deferred.

---

## 10. Notifications Permissions

| Action | System | Sender | Recipient | Other |
|---|---:|---:|---:|---:|
| Create notification | نعم | عبر service فقط | لا | لا |
| Read notification | لا | لا | نعم فقط | لا |
| Mark as read | لا | لا | نعم فقط | لا |

---

## 11. Audit Permissions

| Action | System | Organizer | User | Viewer |
|---|---:|---:|---:|---:|
| Create audit event | نعم/service | indirectly | indirectly | لا |
| Read audit events | support/admin لاحقًا | ربما own tournament later | لا | لا |
| Delete audit event | لا | لا | لا | لا |

Audit logs يجب ألا تكون قابلة للحذف من client.

---

## 12. Firestore Rules Requirements by Area

### 12.1 Tournaments

Rules must enforce:

- only organizer can update tournament admin fields.
- non-organizer cannot generate/update fixtures.
- public read is separate from admin write.
- tournament operations cannot be inferred from visibility.

### 12.2 Teams

Rules must enforce:

- only owner/captain can edit roster.
- player cannot promote himself.
- guest claim link writes must be authorized.

### 12.3 Tournament registration

Rules must enforce:

- captain can submit own team.
- organizer can approve/reject.
- random user cannot approve his own team unless he is organizer.

### 12.4 Matches and scores

Rules must enforce:

- only authorized submitter can submit score.
- only organizer can approve/lock if V1 design chooses organizer approval.
- completed/locked matches cannot be edited casually.

### 12.5 ClaimCodes

Already hardened partially:

- exact get allowed for authenticated proof-of-possession.
- broad list denied.
- creator-scoped reuse allowed.

Remaining:

- remove raw guest claimCode from public-readable docs later.

---

## 13. Required Tests

### 13.1 Account isolation

- Account A creates team/tournament.
- Account B logs in same app process.
- B does not see A data in owned/managed lists.
- B cannot open A admin operations.
- B cannot mutate A entities through controller/service.

### 13.2 Tournament permissions

- Non-organizer cannot edit tournament.
- Non-organizer cannot approve teams.
- Non-organizer cannot schedule matches.
- Public viewer sees only read-only tournament detail.

### 13.3 Team permissions

- Non-captain cannot add/remove players.
- Non-captain cannot resend guest claim link.
- Captain can manage only own team.

### 13.4 Score permissions

- Unauthorized user cannot submit/approve score.
- Organizer can approve.
- Approved match cannot be edited without special path.

### 13.5 Rules emulator tests

Required for:

- tournament writes.
- team membership writes.
- tournament registration writes.
- match score approval writes.
- claim code reads/writes.

---

## 14. Red Flags in Current Code to Audit

هذه ليست اتهامات مؤكدة، بل أشياء يجب فحصها:

- أي controller مسجل `permanent: true` ويحمل user-scoped state.
- أي tournament query بلا `organizerId/currentUid/role` في managed list.
- أي `canManage` عام بدون entity-specific role.
- أي admin button يظهر بناءً على وجود data لا role.
- أي Firestore rule تستخدم `isAuthenticated()` فقط للكتابة.
- أي public screen يعرض admin operations.
- أي cached Firestore data تظهر بعد uid switch.

---

## 15. Decisions Still Needed

1. هل captain يستطيع submit score أم organizer فقط؟
2. هل viceCaptain له صلاحيات V1 أم يؤجل؟
3. هل tournament له منظم واحد فقط في V1؟ المقترح: نعم.
4. هل public tournaments تظهر لكل المستخدمين؟ نعم read-only فقط.
5. هل player search يدخل V1؟ فقط لو team invites جاهزة.
6. هل registration approval إجباري لكل بطولة؟ المقترح: نعم.
7. هل match scheduledAt إجباري قبل publish؟ المقترح: نعم.
8. هل standings تعتمد فقط approved matches؟ المقترح: نعم.

---

## 16. Immediate Outcome

لا يجب تنفيذ أي feature جديدة قبل عمل gap audit للكود الحالي مقابل هذه الوثيقة.

الخطوة التالية بعد هذه الوثيقة:

```text
Tournament Lifecycle & Scheduling Blueprint
```

ثم:

```text
Current Code Permission Gap Audit
```
