import 'package:flutter/material.dart';

class FantasyLeaderboardScreen extends StatelessWidget {
  const FantasyLeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('دوري الحرّيف العالمي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF1E293B),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () {},
          )
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildPodiumSection(context)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: _buildListHeader(),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                // محاكاة باقي الترتيب الرياضي المتسلسل من الرابع حتى العاشر
                final rank = index + 4;
                return _buildLeaderboardRow(
                  rank: rank,
                  teamName: 'أسود الرافدين $rank',
                  managerName: 'الكابتن علي',
                  gwPoints: 40 + (10 - index),
                  totalPoints: 1000 - (index * 15),
                  trend: (index % 3 == 0)
                      ? RankTrend.up
                      : ((index % 2 == 0) ? RankTrend.down : RankTrend.same),
                );
              },
              childCount: 7,
            ),
          ),
          // مساحة إضافية في الأسفل
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  /// منصة التتويج البارزة لأوائل العالم (المركز الأول، الثاني، الثالث)
  Widget _buildPodiumSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 32, bottom: 24, left: 16, right: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildPodiumItem(rank: 2, teamName: 'الفراعنة', points: 1055, color: const Color(0xFFC0C0C0), height: 120),
          const SizedBox(width: 8),
          _buildPodiumItem(rank: 1, teamName: 'ملوك اللعبة', points: 1102, color: const Color(0xFFFFD700), height: 160, isFirst: true),
          const SizedBox(width: 8),
          _buildPodiumItem(rank: 3, teamName: 'الصقور الخضر', points: 1020, color: const Color(0xFFCD7F32), height: 100),
        ],
      ),
    );
  }

  Widget _buildPodiumItem({
    required int rank,
    required String teamName,
    required int points,
    required Color color,
    required double height,
    bool isFirst = false,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (isFirst) const Icon(Icons.workspace_premium, color: Color(0xFFFFD700), size: 40),
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 3),
            image: const DecorationImage(
              image: NetworkImage('https://via.placeholder.com/60'), // صورة رمزية بروفايل المدرب
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(teamName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        Text('$points', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        Container(
          width: 80,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.6), color.withValues(alpha: 0.1)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
            border: Border(top: BorderSide(color: color, width: 2)),
          ),
          child: Center(
            child: Text(
              '$rank',
              style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
            ),
          ),
        ),
      ],
    );
  }

  /// الترويسة الرئيسية لقائمة المتصدرين العادية
  Widget _buildListHeader() {
    return const Row(
      children: [
        SizedBox(width: 40, child: Text('م', style: TextStyle(color: Colors.white54, fontSize: 12), textAlign: TextAlign.center)),
        Expanded(
          flex: 4,
          child: Text('الفريق / المدرب', style: TextStyle(color: Colors.white54, fontSize: 12)),
        ),
        Expanded(
          flex: 1,
          child: Text('الجولة', style: TextStyle(color: Colors.white54, fontSize: 12), textAlign: TextAlign.center),
        ),
        Expanded(
          flex: 2,
          child: Text('النقاط', style: TextStyle(color: Colors.white54, fontSize: 12), textAlign: TextAlign.right),
        ),
      ],
    );
  }

  /// شكل السطر العادي الذي يمثل مدرباً في اللوحة
  Widget _buildLeaderboardRow({
    required int rank,
    required String teamName,
    required String managerName,
    required int gwPoints,
    required int totalPoints,
    required RankTrend trend,
  }) {
    IconData trendIcon;
    Color trendColor;
    switch (trend) {
      case RankTrend.up:
        trendIcon = Icons.arrow_drop_up;
        trendColor = const Color(0xFF32D74B);
        break;
      case RankTrend.down:
        trendIcon = Icons.arrow_drop_down;
        trendColor = Colors.redAccent;
        break;
      case RankTrend.same:
        trendIcon = Icons.remove;
        trendColor = Colors.white30;
        break;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          // المركز واتجاه الصعود
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Text('$rank', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Icon(trendIcon, color: trendColor, size: 20),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // الفريق والمدرب
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(teamName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(managerName, style: const TextStyle(color: Colors.white54, fontSize: 10)),
              ],
            ),
          ),
          // نقاط الجولة الحالية
          Expanded(
            flex: 1,
            child: Text('$gwPoints', style: const TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
          ),
          // إجمالي النقاط العام
          Expanded(
            flex: 2,
            child: Text(
              '$totalPoints',
              style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w900, fontSize: 16),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

enum RankTrend { up, down, same }
