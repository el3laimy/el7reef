import 'package:flutter/material.dart';

import '../../../../domain/entities/player_fantasy_value.dart';
import '../../../../core/widgets/tier_badge_widget.dart';

class FantasyTeamScreen extends StatelessWidget {
  const FantasyTeamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'تشكيلتي (Live Points)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white70),
            tooltip: 'تاريخ الجولات',
            onPressed: () {},
          )
        ],
      ),
      body: Column(
        children: [
          _buildLiveHeader(),
          Expanded(
            child: _buildLivePitchView(),
          ),
          _buildLiveBenchSection(),
        ],
      ),
    );
  }

  /// شريط العارضة العلوية الذي يعرض إجمالي نقاط الجولة والخواص النشطة
  Widget _buildLiveHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('نقاط الجولة (GW 4)', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text(
                '45',
                style: TextStyle(color: Color(0xFF38BDF8), fontSize: 26, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('الخواص النشطة', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                ),
                child: const Text(
                  'Triple Captain',
                  style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// رقعة الملعب وفيها اللاعبين الفعليين
  Widget _buildLivePitchView() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF229954), 
            Color(0xFF27AE60), 
            Color(0xFF229954),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 50),
            blurRadius: 10,
          )
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
           // خطوط الملعب
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

          // توزيع خانات اللاعبين الحقيقيين بالنقط
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLivePlayer(name: 'اللاعب 10', points: '12', tier: PlayerTier.gold, isCaptain: true),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildLivePlayer(name: 'اللاعب 7', points: '5', tier: PlayerTier.silver),
                  _buildLivePlayer(name: 'اللاعب 8', points: '3', tier: PlayerTier.bronze),
                ],
              ),
              _buildLivePlayer(name: 'مدافعنا', points: '6', tier: PlayerTier.silver, isViceCaptain: true),
              _buildLivePlayer(name: 'حارس بطل', points: '8', tier: PlayerTier.bronze),
            ],
          ),
        ],
      ),
    );
  }

  /// دكة البدلاء
  Widget _buildLiveBenchSection() {
    return Container(
      height: 140,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(top: BorderSide(color: Color(0xFF38BDF8), width: 3)),
      ),
      child: Column(
        children: [
          const Text(
            'مقاعد البدلاء',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLivePlayer(name: 'احتياط 1', points: '-', tier: PlayerTier.bronze, isBench: true),
              _buildLivePlayer(name: 'احتياط 2', points: '2', tier: PlayerTier.bronze, isBench: true),
            ],
          ),
        ],
      ),
    );
  }

  /// تصمیم کارت اللاعب الحقيقي في شاشة التشكيلة
  Widget _buildLivePlayer({
    required String name, 
    required String points, 
    required PlayerTier tier,
    bool isCaptain = false,
    bool isViceCaptain = false,
    bool isBench = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.topRight,
          clipBehavior: Clip.none,
          children: [
            // صورة اللاعب مع بادج النُدرة كشارة جانبية
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                ClipOval(
                  child: Container(
                    color: Colors.grey.shade800,
                    width: isBench ? 36 : 46,
                    height: isBench ? 36 : 46,
                    child: Icon(Icons.person, color: Colors.white54, size: isBench ? 24 : 30),
                  ),
                ),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: TierBadgeWidget(
                    tier: tier,
                    size: isBench ? 16 : 20,
                  ),
                ),
              ],
            ),
            // علامة الكابتن
            if (isCaptain || isViceCaptain)
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    isCaptain ? 'C' : 'V',
                    style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        // اسم اللاعب
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withValues(alpha: 220),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
            border: Border.all(color: Colors.white10),
          ),
          child: Text(
            name,
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // نقاط اللاعب الحية
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          decoration: BoxDecoration(
            color: isBench ? Colors.grey.shade700 : const Color(0xFF38BDF8),
            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(4), bottomRight: Radius.circular(4)),
          ),
          child: Text(
            isBench && points == '-' ? '-' : points,
            style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}
