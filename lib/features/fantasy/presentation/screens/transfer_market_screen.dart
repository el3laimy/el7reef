import 'package:flutter/material.dart';

import '../../../../domain/entities/player_fantasy_value.dart';
import '../../../../core/widgets/tier_badge_widget.dart';

/// شاشة سوق الانتقالات (الميركاتو) لتبديل اللاعبين وتلقي الخصومات
class TransferMarketScreen extends StatefulWidget {
  const TransferMarketScreen({super.key});

  @override
  State<TransferMarketScreen> createState() => _TransferMarketScreenState();
}

class _TransferMarketScreenState extends State<TransferMarketScreen> {
  // متغيرات للعرض (Mocking)
  final double _remainingBudget = 1.5;
  final int _freeTransfers = 1;
  final int _hitPoints = -4; // تظهر عندما نقوم بتبديل إضافي
  final bool _isWildcardActive = false; // إذا تفعلت، يختفي الخصم

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('سوق الانتقالات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF1E293B),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white70),
            onPressed: () {},
          )
        ],
      ),
      body: Column(
        children: [
          _buildTransferMetrix(),
          _buildWildcardBanner(),
          Expanded(child: _buildTransferPitch()),
        ],
      ),
      bottomNavigationBar: _buildConfirmBar(),
    );
  }

  /// شريط مقاييس وتعقيدات الانتقالات
  Widget _buildTransferMetrix() {
    return Container(
      color: const Color(0xFF1E293B),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMetricItem(label: 'تبديل مجاني', value: '$_freeTransfers', valueColor: Colors.white),
          Container(width: 1, height: 30, color: Colors.white10),
          _buildMetricItem(
            label: 'الخصم',
            value: _hitPoints < 0 && !_isWildcardActive ? '$_hitPoints' : '0',
            valueColor: _hitPoints < 0 && !_isWildcardActive ? Colors.redAccent : Colors.white,
          ),
          Container(width: 1, height: 30, color: Colors.white10),
          _buildMetricItem(label: 'يتوفر', value: '${_remainingBudget}M', valueColor: const Color(0xFF32D74B)),
        ],
      ),
    );
  }

  Widget _buildMetricItem({required String label, required String value, required Color valueColor}) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: valueColor, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }

  /// شريط تفعيل کارت الوايلدكارد
  Widget _buildWildcardBanner() {
    return Container(
      width: double.infinity,
      color: Colors.amber.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.star, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Text(
                'الوايلدكارد متاح (تغيير الفريق مجاناً)',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          TextButton(
            onPressed: () {
              // TODO: Activate Wildcard
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              minimumSize: const Size(60, 24),
              backgroundColor: Colors.amber,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('تفعيل', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  /// الملعب المخصص للانتقالات
  Widget _buildTransferPitch() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF229954), 
            Color(0xFF1E8449), 
            Color(0xFF196F3D),
          ],
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 50), blurRadius: 10)
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTransferPlayer(name: 'اللاعب 10', tier: PlayerTier.gold, price: '8.5M', status: TransferStatus.none),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTransferPlayer(name: 'اللاعب 7', tier: PlayerTier.silver, price: '6.0M', status: TransferStatus.removed),
              _buildTransferPlayer(name: 'لاعب جديد', tier: PlayerTier.silver, price: '5.5M', status: TransferStatus.added),
            ],
          ),
          _buildTransferPlayer(name: 'مدافعنا', tier: PlayerTier.silver, price: '4.5M', status: TransferStatus.none),
          _buildTransferPlayer(name: 'حارس بطل', tier: PlayerTier.bronze, price: '4.0M', status: TransferStatus.none),
        ],
      ),
    );
  }

  /// عنصر اللاعب أثناء التبديل
  Widget _buildTransferPlayer({
    required String name,
    required PlayerTier tier,
    required String price,
    required TransferStatus status,
  }) {
    final bool isAdded = status == TransferStatus.added;
    final bool isRemoved = status == TransferStatus.removed;

    return GestureDetector(
      onTap: () {
        // TODO: عرض نافذة الاستبدال (Replace/Info)
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            clipBehavior: Clip.none,
            children: [
              Opacity(
                opacity: isRemoved ? 0.4 : 1.0,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    ClipOval(
                      child: Container(
                        color: Colors.grey.shade800,
                        width: 42,
                        height: 42,
                        child: const Icon(Icons.person, color: Colors.white54, size: 26),
                      ),
                    ),
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: TierBadgeWidget(
                        tier: tier,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
              // أيقونات الحالة IN / OUT
              if (isAdded)
                Positioned(
                  top: -8,
                  left: -8,
                  child: Container(
                    decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                    padding: const EdgeInsets.all(2),
                    child: const Icon(Icons.arrow_upward, size: 14, color: Colors.white),
                  ),
                ),
              if (isRemoved)
                Positioned(
                  top: -8,
                  right: -8,
                  child: Container(
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    padding: const EdgeInsets.all(2),
                    child: const Icon(Icons.arrow_downward, size: 14, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isRemoved ? Colors.red.withValues(alpha: 0.8) : (isAdded ? Colors.green.withValues(alpha: 0.8) : const Color(0xFF1E293B)),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white10),
            ),
            child: Text(
              name,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                decoration: isRemoved ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
            child: Text(price, style: const TextStyle(color: Colors.white54, fontSize: 10)),
          ),
        ],
      ),
    );
  }

  /// شريط اعتماد الصفقات بأسفل الشاشة
  Widget _buildConfirmBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: Colors.white54),
                ),
                child: const Text('إلغاء', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: const Color(0xFF38BDF8),
                ),
                child: const Text('اعتماد الصفقات', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum TransferStatus { none, added, removed }
