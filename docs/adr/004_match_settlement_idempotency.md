<div dir="rtl">

# ADR-004 — Idempotency لتسوية المباراة

**الحالة:** مقبول ومُنفّذ  
**التاريخ:** 2026-07-13

## السياق

قد يعيد العميل طلب تسوية النتيجة بعد timeout أو انقطاع الشبكة. إنشاء MatchEvents أو player stats مرة ثانية يضاعف الأهداف والتقييمات.

## القرار

يطبّع الخادم payload التسوية ثم يحسب بصمة <bdi dir="ltr">SHA-256</bdi> حتمية. تُحفظ البصمة والفاعل ووقت الإرسال على وثيقة المباراة داخل transaction نفسها.

- إعادة نفس payload بعد النجاح ترجع <bdi dir="ltr">alreadySettled: true</bdi> دون كتابة جديدة.
- payload مختلف بعد اكتمال المباراة يُرفض.
- event ids للأهداف وMVP حتمية، وكل قراءات transaction تسبق الكتابات.
- controller لا يكتب MatchEvents عند retry؛ يعيد الطلب عبر <bdi dir="ltr">MatchSettlementService</bdi> وحدّ الخادم فقط.

## النتائج

التسوية أصبحت atomic وقابلة لإعادة المحاولة. أي تغيير مقصود للنتيجة بعد التسوية يحتاج مسار dispute/approval، وليس إعادة استخدام submit.

## التحقق

- <bdi dir="ltr">test/functions/settlement_core.test.js</bdi>
- retry متزامن ومتتابع داخل <bdi dir="ltr">functions/scripts/emulator_smoke.js</bdi>
- <bdi dir="ltr">test/features/match/score_submit_controller_test.dart</bdi>

</div>
