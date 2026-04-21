<div dir="rtl" align="right">

<h1>مواءمة الرؤية الرئيسية مع الخطة الحالية</h1>

<h2>الغرض من الملف</h2>

<p>
هذا الملف يوضح ما الذي تغطيه الخطة الحالية بالفعل من الرؤية الكبرى للتطبيق، وما الذي ما زال ناقصًا أو ممثلًا بشكل أضعف من المطلوب.
</p>

<p>
الهدف ليس إعادة كتابة الرؤية، بل تحويلها إلى فجوات تنفيذية واضحة يمكن إضافتها إلى الـ backlog الحالية.
</p>

<h2>ما الذي أصبح مغطى بالفعل من الرؤية؟</h2>

<ul>
  <li>دعم اللاعبين غير المسجلين و<code>GuestPlayer</code> كأساس دوميني موجود.</li>
  <li>دعم الفرق غير المسجلة و<code>GuestTeam</code> داخل المسارات التشغيلية.</li>
  <li>مسارات <code>claim</code> و<code>replace</code> و<code>share links</code> موجودة كقاعدة قوية للنمو الواقعي.</li>
  <li>إدارة القوائم والتشكيل و<code>matchday truth</code> موجودة كأساس مهم للثقة التشغيلية.</li>
  <li>الدورات لم تعد مجرد تسجيلات، بل تملك participants, fixtures, standings, bracket, operations dashboard.</li>
  <li>الفنتازي تملك foundation حقيقية ومتصلة جزئيًا بواقع المباراة.</li>
  <li>التدقيق والـ audit والـ disputes أصبحت جزءًا من المنتج وليس فكرة مستقبلية فقط.</li>
</ul>

<h2>ما الذي ما زال ناقصًا أو أضعف من الرؤية؟</h2>

<h3>1. هوية اللاعب ما زالت أضعف من الرؤية المقصودة</h3>

<p>
الرؤية تطلب أن تكون هوية اللاعب أعمق من مجرد الاسم والصورة والمركز.
</p>

<p>
الموجود حاليًا في <code>Player</code> و<code>Profile</code> جيد كبداية، لكنه ما زال محدودًا في:
</p>

<ul>
  <li><code>preferred foot</code> غير موجودة</li>
  <li><code>playing style</code> غير موجودة</li>
  <li>تاريخ الفرق وتاريخ البطولات غير ظاهرين كلاعب كهوية حية</li>
  <li>السمعة والسلوك والثقة موجودة بشكل أولي عبر <code>trustWeight/trustLevel</code> لكن ليست مبنية كسطح منتج مكتمل</li>
  <li>لا توجد player cards غنية أو reputation summary حقيقي</li>
</ul>

<h3>2. البحث والاكتشاف ما زالا ضيقين مقارنة بالرؤية</h3>

<p>
الرؤية تتكلم عن <code>Search / Explore</code> كمحرك نمو رئيسي.
</p>

<p>
لكن الموجود حاليًا يميل إلى:
</p>

<ul>
  <li>بحث لاعبين موجه للأصدقاء فقط</li>
  <li>بعض البحث الموضعي للفرق داخل شاشات محددة</li>
  <li>غياب search service موحدة للاعبين والفرق والبطولات</li>
  <li>غياب Explore surface حقيقية تجمع الفرص والكيانات المهمة</li>
</ul>

<h3>3. طبقة الإشعارات ما زالت شبه غائبة كمنتج</h3>

<p>
الرؤية تعتبر الإشعارات أساسية في:
</p>

<ul>
  <li>الدعوات</li>
  <li>التسجيلات</li>
  <li>التحديثات التنظيمية</li>
  <li>مطالبات <code>claim</code></li>
  <li>تذكيرات المباريات</li>
</ul>

<p>
لكن في التنفيذ الحالي لا يوجد بعد:
</p>

<ul>
  <li><code>Notification</code> domain/service واضح</li>
  <li>in-app inbox حقيقي</li>
  <li>قواعد توجيه للأحداث الأساسية</li>
  <li>تفريق جيد بين notification delivery وnotification storage</li>
</ul>

<h3>4. دعوات الفريق موجودة، لكن join requests ليست first-class flow بعد</h3>

<p>
الرؤية تتحدث عن:
</p>

<ul>
  <li>invite</li>
  <li>join team</li>
  <li>join requests</li>
</ul>

<p>
الموجود الآن قوي في invite والclaim، لكن user-initiated join request flow لا تظهر كمسار منتج أولي واضح ومتكامل بنفس الدرجة.
</p>

<h3>5. الرؤية الهندسية الخاصة بالـ provider abstraction لم تنعكس بالكامل بعد</h3>

<p>
المشروع تحرك في اتجاه repositories وservices، وهذا جيد جدًا.
</p>

<p>
لكن لا يزال لدينا coupling واضح في بعض النقاط الحساسة مثل:
</p>

<ul>
  <li><code>AuthService</code> مرتبطة مباشرة بـ <code>FirebaseAuth</code></li>
  <li><code>PhotoUploadService</code> مرتبطة مباشرة بـ <code>FirebaseStorage</code></li>
  <li>لا توجد بعد عقود صريحة لـ <code>StorageService</code> أو <code>MapService</code> أو <code>MatchDataProvider</code></li>
</ul>

<p>
وهذا مهم لأن الرؤية نفسها شددت على المرونة ضد provider lock-in.
</p>

<h3>6. طبقة البيانات المستقبلية للمباريات ما زالت تحتاج boundary أوضح</h3>

<p>
الرؤية تذكر بوضوح أن أي APIs خارجية يجب أن تمر من خلال طبقة backend sync / normalization، لا من خلال client logic مباشر.
</p>

<p>
في الخطة الحالية لا توجد بعد تذكرة صريحة توضح:
</p>

<ul>
  <li>عقد <code>MatchDataProvider</code></li>
  <li>boundary بين external ingestion وبين canonical internal truth</li>
  <li>كيف سنحمي fantasy وanalytics مستقبلاً من provider coupling</li>
</ul>

<h2>ما الذي لا أعتبره ناقصًا رغم أنه ما زال يمكن تحسينه؟</h2>

<ul>
  <li>دعم unregistered players/teams: موجود كاتجاه قوي ومطبق جزئيًا بالفعل.</li>
  <li>claim flow: موجودة كأساس جيد.</li>
  <li>team roster / formation / role management: موجودة كأساس قوي للفرق المسجلة.</li>
  <li>tournament flexibility: أصبحت الآن قلب الخطة الحالية، لا gap منسية.</li>
</ul>

<h2>ما الذي تمت إضافته للخطة الحالية بناءً على هذه المراجعة؟</h2>

<p>
تمت إضافة ثلاث كتل جديدة إلى الـ backlog:
</p>

<ul>
  <li><strong>Player Identity and Credibility</strong></li>
  <li><strong>Discovery, Join, and Notifications</strong></li>
  <li><strong>Platform Abstractions and Data Interfaces</strong></li>
</ul>

<p>
وتشمل التذاكر الجديدة:
</p>

<ul>
  <li><code>V2-045</code> إلى <code>V2-048</code>: تعميق هوية اللاعب وplayer cards والسمعة والتاريخ</li>
  <li><code>V2-049</code> إلى <code>V2-053</code>: search/explore موحد، join requests، والإشعارات</li>
  <li><code>V2-054</code> إلى <code>V2-056</code>: auth/storage/maps/external match data abstractions</li>
</ul>

<h2>الترتيب الصحيح بالنسبة للخطة الحالية</h2>

<p>
هذه الإضافات ليست قبل إصلاح مسار البطولة الحالي.
</p>

<p>
الترتيب الصحيح أصبح:
</p>

<ol>
  <li>إغلاق <code>TOS-FIX-001</code> إلى <code>TOS-FIX-031</code></li>
  <li>العودة إلى <code>V2-039</code> إلى <code>V2-044</code> إذا كانت ما زالت مطلوبة في نفس المسار</li>
  <li>ثم فتح <code>V2-045</code> إلى <code>V2-056</code> كمرحلة مواءمة مع الرؤية الأشمل</li>
</ol>

<p>
وهذا يحافظ على مبدأ مهم:
</p>

<p>
لا نوسع السطح الاجتماعي أو الهوياتي أو الهندسي قبل تثبيت الحلقة التشغيلية الأساسية للبطولة.
</p>

<h2>الخلاصة التنفيذية</h2>

<p>
الرؤية الكبرى ليست منفصلة عن الخطة الحالية، بل جزء كبير منها أصبح ممثلًا بالفعل.
</p>

<p>
لكن ما كان ناقصًا فعلاً وتمت إضافته الآن هو:
</p>

<ul>
  <li>تعميق هوية اللاعب</li>
  <li>البحث والاكتشاف الموحد</li>
  <li>الإشعارات كطبقة منتج حقيقية</li>
  <li>join requests كجزء من team growth loop</li>
  <li>تجريدات الـ providers والـ external data boundaries</li>
</ul>

<p>
وبهذا تصبح الخطة الحالية أقرب بكثير إلى الرؤية الرئيسية للتطبيق، لا إلى مجرد إصلاحات موضعية في البطولة فقط.
</p>

</div>
