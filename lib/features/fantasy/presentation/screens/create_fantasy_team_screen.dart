import 'package:flutter/material.dart';

class CreateFantasyTeamScreen extends StatefulWidget {
  const CreateFantasyTeamScreen({super.key});

  @override
  State<CreateFantasyTeamScreen> createState() => _CreateFantasyTeamScreenState();
}

class _CreateFantasyTeamScreenState extends State<CreateFantasyTeamScreen> {
  // للتبسيط في العرض، نفترض أننا نبني تشكيلة خماسية (5 أساسي + 2 احتياط)
  double _remainingBudget = 100.0; // ignore: prefer_final_fields
  int _playersSelected = 0; // ignore: prefer_final_fields

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'بناء التشكيلة (Draft)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.amber),
            tooltip: 'Auto Pick (تلقائي)',
            onPressed: () {
              // TODO: استدعاء AutoPickEngine لتعبئة التشكيلة التلقائية
            },
          )
        ],
      ),
      body: Column(
        children: [
          _buildBudgetHeader(),
          Expanded(
            child: _buildPitchView(),
          ),
          _buildBenchSection(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: التحقق من التشكيلة (Mins, Tiers, Budget) ثم الحفظ
        },
        backgroundColor: const Color(0xFF32D74B),
        icon: const Icon(Icons.check, color: Colors.white),
        label: const Text('اعتماد', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  /// شريط العارضة العلوية الذي يعرض الميزانية واللاعبين والندرة
  Widget _buildBudgetHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('الميزانية المتبقية', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text(
                '${_remainingBudget.toStringAsFixed(1)}M',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('اللاعبون المحترفون', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Row(
                children: [
                  Text(
                    '$_playersSelected / 7',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  // مؤشرات المستوى المتاحة
                  Icon(Icons.star, color: Colors.amber.shade300, size: 16), // Gold Limit Indicator
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// رقعة الملعب التي يتم توزيع الخانات عليها
  Widget _buildPitchView() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF229954), // أخضر غامق
            Color(0xFF27AE60), // أخضر عشبي
            Color(0xFF229954),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 50),
            blurRadius: 10,
            spreadRadius: 2,
          )
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // رسم خطوط الملعب التوضيحية
          Positioned(
            top: 0,
            child: Container(
              width: 150,
              height: 60,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white30, width: 2),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
            ),
          ),
          Positioned(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white30, width: 2),
              ),
            ),
          ),
          Container(
            height: 2,
            width: double.infinity,
            color: Colors.white30,
          ),

          // توزيع خانات التشكيلة (1 GK, 1 DEF, 2 MID, 1 FWD) - نموذج خماسي
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSlot(role: 'مهاجم', position: 'FWD'),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSlot(role: 'خط وسط', position: 'MID'),
                  _buildSlot(role: 'خط وسط', position: 'MID'),
                ],
              ),
              _buildSlot(role: 'مدافع', position: 'DEF'),
              _buildSlot(role: 'حارس', position: 'GK'),
            ],
          ),
        ],
      ),
    );
  }

  /// منطقة دكة الاحتياط
  Widget _buildBenchSection() {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(top: BorderSide(color: Color(0xFF38BDF8), width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'دكة البدلاء (Bench)',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSlot(role: 'بديل 1', position: 'SUB', isBench: true),
              _buildSlot(role: 'بديل 2', position: 'SUB', isBench: true),
            ],
          ),
        ],
      ),
    );
  }

  /// تصميم أيقونة تيشرت اللاعب لخانة واحدة داخل الملعب
  Widget _buildSlot({required String role, required String position, bool isBench = false}) {
    return GestureDetector(
      onTap: () {
        // TODO: توجيه المستخدم لصفحة Player Picker
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Icon(
                Icons.person_add_alt_1_rounded, // قميص افتراضي فارغ (Add)
                size: isBench ? 40 : 50,
                color: Colors.white.withValues(alpha: 200),
              ),
              // يمكنك إضافة علامة (C) كابتن هنا كـ Stack صغير إن لزم
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isBench ? const Color(0xFF334155) : const Color(0xFF0F172A).withValues(alpha: 200),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white24, width: 1),
            ),
            child: Text(
              position,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'أضف لاعب',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
