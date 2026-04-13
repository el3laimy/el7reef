import 'package:flutter/material.dart';

class FantasyLeagueListScreen extends StatelessWidget {
  const FantasyLeagueListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // خلفية داكنة فاخرة تناسب الفانتازي
      appBar: AppBar(
        title: const Text(
          'الفانتازي (الرئيسية)',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStatsGlassmorphicCard(context),
              const SizedBox(height: 24),
              const Text(
                'البطولات والدوريات الكبرى',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildLeagueItem(
                title: 'دوري الحرّيف العالمي (Global)',
                rank: '142,005',
                isGlobal: true,
              ),
              const SizedBox(height: 12),
              _buildLeagueItem(
                title: 'دوري الأصدقاء (VIP)',
                rank: '3',
                isGlobal: false,
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: الانتقال إلى شاشة إدارة التشكيلة (My Team)
        },
        backgroundColor: const Color(0xFF38BDF8),
        icon: const Icon(Icons.sports_soccer_rounded, color: Colors.white),
        label: const Text(
          'فريقي',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  /// بطاقة زجاجية مُبهرة لعرض إحصائيات الفريق الأساسية
  Widget _buildStatsGlassmorphicCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E293B).withValues(alpha: 200),
            const Color(0xFF0F172A).withValues(alpha: 150),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 25), // حدود زجاجية متوهجة خفيفة
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF38BDF8).withValues(alpha: 25),
            offset: const Offset(0, 10),
            blurRadius: 30,
          ),
        ],
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const Text(
            'حصد النقاط',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          const Text(
            '1,085',
            style: TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatMetric(label: 'نقاط الجولة', value: '45'),
              Container(width: 1, height: 40, color: Colors.white24),
              _buildStatMetric(label: 'الترتيب العام', value: '#142K'),
              Container(width: 1, height: 40, color: Colors.white24),
              _buildStatMetric(label: 'الميزانية', value: '1.5M'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatMetric({required String label, required String value}) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF38BDF8),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  /// بناء عنصر قائمة الدوريات (Mini Leagues)
  Widget _buildLeagueItem({required String title, required String rank, required bool isGlobal}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: isGlobal ? Colors.amber.withValues(alpha: 50) : Colors.purple.withValues(alpha: 50),
          child: Icon(
            isGlobal ? Icons.public : Icons.group,
            color: isGlobal ? Colors.amber : Colors.purpleAccent,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: const Text(
          'اضغط لعرض الترتيب',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text('المركز', style: TextStyle(color: Colors.white70, fontSize: 10)),
            Text(
              rank,
              style: const TextStyle(
                color: Color(0xFF32D74B), // لون أخضر يشير للارتقاء
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        onTap: () {
          // TODO: الانتقال لصفحة ترتيب الدوري الفرعي
        },
      ),
    );
  }
}
