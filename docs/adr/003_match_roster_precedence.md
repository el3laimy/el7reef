<div dir="rtl">

# ADR-003 — أسبقية roster المباراة

**الحالة:** مقبول ومُنفّذ  
**التاريخ:** 2026-07-13

## السياق

تسوية النتيجة تحتاج قائمة هوية ثابتة للطرفين، بينما قد تأتي البيانات من lineup مجمدة، أو roster فريق قابل للتغيير، أو لاعبي طرف المباراة المؤقتين. الاعتماد على roster الحالي فقط يسمح لعضو متأخر بالدخول في إحصائيات مباراة سابقة.

## القرار

يستخدم الخادم <bdi dir="ltr">functions/match_roster.js</bdi> بالأسبقية التالية لكل طرف:

1. snapshot التشكيلة عند وجودها، من <bdi dir="ltr">starters</bdi> و<bdi dir="ltr">bench</bdi>، مع قراءة <bdi dir="ltr">entries</bdi> القديمة.
2. عند غياب snapshot فقط: عضويات الفريق الرسمية ذات الحالة <bdi dir="ltr">starter</bdi> أو <bdi dir="ltr">bench</bdi>، أو لاعبو فريق الضيوف حسب نوع participant.
3. يضاف <bdi dir="ltr">matchSidePlayer</bdi> دائمًا للطرف المنسوب إليه.

لا يسمح الخادم بتجاوز التحقق عندما تكون النتيجة فارغة، وتظل مفاتيح الطرفين منفصلة لمنع إسناد هدف للطرف المقابل.

## النتائج

- snapshot المجمدة تحمي تاريخ المباراة من تغير roster لاحقًا.
- المباراة بلا lineup تظل قابلة للتسوية من roster الحقيقي.
- قراءات roster محدودة بقيم <bdi dir="ltr">ROSTER_READ_LIMITS</bdi> لمنع fan-out غير مقيد.

## التحقق

- <bdi dir="ltr">test/functions/match_roster.test.js</bdi>
- <bdi dir="ltr">test/functions/settlement_payload.test.js</bdi>
- <bdi dir="ltr">functions/scripts/emulator_smoke.js</bdi>

</div>
