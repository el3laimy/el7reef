import 'package:flutter/material.dart';

import '../../../../domain/entities/player_fantasy_value.dart';
import '../../../../core/widgets/tier_badge_widget.dart';

class PlayerPickerScreen extends StatefulWidget {
  const PlayerPickerScreen({super.key});

  @override
  State<PlayerPickerScreen> createState() => _PlayerPickerScreenState();
}

class _PlayerPickerScreenState extends State<PlayerPickerScreen> {
  String _selectedPositionFilter = 'الكل';
  final List<String> _positions = ['الكل', 'حارس', 'مدافع', 'خط وسط', 'مهاجم'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('اختيار لاعب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF1E293B),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(130),
          child: _buildFilterHeader(),
        ),
      ),
      body: _buildPlayersList(),
    );
  }

  /// رأس الفلاتر وأدوات البحث المتقدمة
  Widget _buildFilterHeader() {
    return Container(
      color: const Color(0xFF1E293B),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // شريط البحث
          TextField(
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'ابحث عن اسم لاعب أو فريق...',
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              filled: true,
              fillColor: const Color(0xFF0F172A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
          const SizedBox(height: 12),
          // فلاتر المراكز
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _positions.length,
              itemBuilder: (context, index) {
                final pos = _positions[index];
                final isSelected = pos == _selectedPositionFilter;
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ChoiceChip(
                    label: Text(pos),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedPositionFilter = pos;
                        });
                      }
                    },
                    selectedColor: const Color(0xFF38BDF8),
                    backgroundColor: const Color(0xFF0F172A),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // فلاتر الفرز
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.sort, color: Colors.white70, size: 16),
                label: const Text('النقاط الكلية', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ),
              const Row(
                children: [
                  Text('الميزانية المُتبقية: ', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text('4.5M', style: TextStyle(color: Color(0xFF32D74B), fontWeight: FontWeight.bold)),
                ],
              )
            ],
          )
        ],
      ),
    );
  }

  /// القائمة الرئيسية لعرض اللاعبين المطابقين
  Widget _buildPlayersList() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _buildPlayerListItem(
          name: 'عصام الحرّيف',
          teamName: 'فريق النسور',
          price: '8.5M',
          points: '124',
          ownership: '42%',
          tier: PlayerTier.gold,
        ),
        _buildPlayerListItem(
          name: 'أحمد ماهر',
          teamName: 'أبطال المهندسين',
          price: '6.0M',
          points: '89',
          ownership: '15%',
          tier: PlayerTier.silver,
        ),
        _buildPlayerListItem(
          name: 'مصطفى كامل',
          teamName: 'الزمالك كيدز',
          price: '4.5M',
          points: '40',
          ownership: '5%',
          tier: PlayerTier.bronze,
        ),
      ],
    );
  }

  /// تصميم كارت مُبهر لكل لاعب في سوق الانتقالات
  Widget _buildPlayerListItem({
    required String name,
    required String teamName,
    required String price,
    required String points,
    required String ownership,
    required PlayerTier tier,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Stack(
          alignment: Alignment.bottomRight,
          children: [
            ClipOval(
              child: Container(
                color: Colors.grey.shade800,
                width: 44,
                height: 44,
                child: const Icon(Icons.person, color: Colors.white54, size: 28),
              ),
            ),
            Positioned(
              bottom: -2,
              right: -2,
              child: TierBadgeWidget(
                tier: tier,
                size: 20,
              ),
            ),
          ],
        ),
        title: Text(
          name,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(teamName, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildSubMetric(icon: Icons.star_rounded, value: points, label: 'نقطة'),
                const SizedBox(width: 12),
                _buildSubMetric(icon: Icons.people_rounded, value: ownership, label: 'امتلاك'),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              price,
              style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                // TODO: إضافة للاعب وإغلاق الصفحة أو استدعاء الترانسفير إنجن
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF32D74B),
                minimumSize: const Size(60, 30),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('اختيار', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubMetric({required IconData icon, required String value, required String label}) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.white54),
        const SizedBox(width: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }
}
