<div dir="rtl">

# تقرير Hotspots وميزانية النمو

**التاريخ:** 2026-07-13

يولد <bdi dir="ltr">npm run report:hotspots</bdi> أكبر 20 ملف production حسب الأسطر. يحرس CI أكبر 11 ملفًا معروفًا فقط عند baseline الحالي؛ الملفات الأخرى تظهر للمراقبة دون حد أعمى.

أي ملف محروس لا يُسمح له بالنمو فوق baseline في <bdi dir="ltr">tool/hotspot_budget.json</bdi>. عند الحاجة لسلوك جديد يجب استخراج المسؤولية إلى widget/service/policy، أو تسجيل قرار معماري يغيّر الميزانية وسببه في مراجعة مستقلة.

أُنجزت خلال Waves الحالية عمليات extraction لـScore Submit، شاشة تفاصيل البطولة، dashboard العمليات، guest claim، lifecycle، وpitch layout. تبقى ملفات كبيرة، لكن الميزانية تمنع إضافة مسؤوليات جديدة إليها بصمت.

</div>
