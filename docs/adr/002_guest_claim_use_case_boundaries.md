<div dir="rtl">

# ADR-002 — حدود حالات استخدام استلام اللاعب والفريق الضيف

**الحالة:** معتمد محليًا  
**التاريخ:** <bdi dir="ltr">2026-07-13</bdi>

## السياق

تجمع خدمة <bdi dir="ltr">GuestClaimService</bdi> بين التحقق من رابط الاستلام، كشف تعارضات الدمج، وتنفيذ كتابات مترابطة على عدة مستندات. يجب الحفاظ على أسماء المجموعات وشكل <bdi dir="ltr">claim code</bdi> الحاليين، مع ضمان أن اللاعب الضيف يحتفظ بهويته التاريخية وأن إعادة المحاولة لا تكرر الدمج.

## حالات الاستلام

1. <bdi dir="ltr">active</bdi>: الرابط صالح ويمكن بدء الاستلام.
2. <bdi dir="ltr">approvalRequired</bdi>: طلب استلام الفريق محفوظ وينتظر موافقة منشئ الفريق الضيف.
3. <bdi dir="ltr">claimed</bdi>: تم ربط الهوية الضيفة بالحساب أو الفريق المسجل.
4. <bdi dir="ltr">alreadyClaimed</bdi>: إعادة محاولة مطابقة؛ لا توجد كتابات دمج جديدة.
5. <bdi dir="ltr">conflict</bdi>: الهدف مرتبط بكيان آخر أو يوجد تعارض اسم/هاتف/قائمة فريق.
6. <bdi dir="ltr">expired</bdi>: الرابط تجاوز تاريخ الصلاحية ويُحدّث وضعه قبل رفض العملية.

## القرار

- <bdi dir="ltr">GuestClaimTokenPolicy</bdi> يملك قواعد نوع الرابط والصلاحية والحالات المسموح بها.
- <bdi dir="ltr">GuestClaimMergePolicy</bdi> يملك دمج القوائم ومقارنة المجموعات دون الاعتماد على Firestore.
- تبقى كل كتابات الدمج الحساسة داخل transaction واحدة يملكها <bdi dir="ltr">GuestClaimService</bdi>.
- تسجيل analytics يحدث بعد نجاح transaction، لأن Firestore قد يعيد تشغيل callback أكثر من مرة.
- لا يتغير <bdi dir="ltr">claim code schema</bdi> ولا أسماء collections ضمن هذا التفكيك.

## ملكية الكتابات الحساسة

- استلام اللاعب: <bdi dir="ltr">teamMemberships</bdi> ثم نسخة التوافق في <bdi dir="ltr">teams.playerIds</bdi> عند وجود صلاحية، ثم <bdi dir="ltr">players</bdi> و<bdi dir="ltr">guestPlayers</bdi> و<bdi dir="ltr">claimCodes</bdi> داخل transaction واحدة.
- استلام الفريق: <bdi dir="ltr">teams.tournamentIds</bdi> و<bdi dir="ltr">guestTeams</bdi> و<bdi dir="ltr">claimCodes</bdi> داخل transaction واحدة.
- analytics أثر لاحق غير حاكم لنجاح الاستلام، ولا يُنفذ من داخل transaction.

## ضمانات الفشل وإعادة المحاولة

- تعارض roster لا يترك guest أو membership أو claim code في حالة جزئية.
- إعادة نفس الاستلام ترجع <bdi dir="ltr">alreadyClaimed</bdi> ولا تعيد كتابة الربط.
- حدث اكتمال analytics يُسجل مرة واحدة عند الانتقال الفعلي إلى <bdi dir="ltr">claimed</bdi>، وليس عند retry مطابق.

## التحقق

- <bdi dir="ltr">test/core/services/guest_claim_service_test.dart</bdi> يغطي الاستلام المباشر، الموافقة، انتهاء الصلاحية، تعارضات الاسم والهاتف والـroster، retry، والهوية المرتبطة بعد claim.
- اختبار تعارض roster يثبت عدم وجود كتابات جزئية وعدم تسجيل analytics.

</div>
