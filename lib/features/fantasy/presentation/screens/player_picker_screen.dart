import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/fantasy_market_player.dart';
import '../../../../core/widgets/tier_badge_widget.dart';

class PlayerPickerScreen extends StatefulWidget {
  final List<FantasyMarketPlayer> players;
  final String requiredPosition;
  final List<String> selectedPlayerIds;
  final String? currentPlayerId;
  final double availableBudget;

  const PlayerPickerScreen({
    super.key,
    required this.players,
    required this.requiredPosition,
    required this.selectedPlayerIds,
    required this.availableBudget,
    this.currentPlayerId,
  });

  @override
  State<PlayerPickerScreen> createState() => _PlayerPickerScreenState();
}

class _PlayerPickerScreenState extends State<PlayerPickerScreen> {
  String _search = '';
  String _filter = 'الكل';

  List<String> get _filters => [
        'الكل',
        'GK',
        'DEF',
        'MID',
        'FWD',
      ];

  @override
  Widget build(BuildContext context) {
    final filteredPlayers = widget.players.where((player) {
      final matchesSearch = _search.isEmpty ||
          player.player.name.toLowerCase().contains(_search.toLowerCase()) ||
          (player.player.username?.toLowerCase().contains(_search.toLowerCase()) ??
              false);
      final matchesFilter =
          _filter == 'الكل' || player.positionCode == _filter;
      final matchesSlot = widget.requiredPosition == 'SUB' ||
          player.positionCode == widget.requiredPosition;
      return matchesSearch && matchesFilter && matchesSlot;
    }).toList()
      ..sort(
        (a, b) => b.value.totalFantasyPoints.compareTo(
          a.value.totalFantasyPoints,
        ),
      );

    return Scaffold(
      backgroundColor: const Color(0xFF081120),
      appBar: AppBar(
        title: Text(
          widget.requiredPosition == 'SUB'
              ? 'اختر لاعباً للدكة'
              : 'اختر لاعباً لـ ${widget.requiredPosition}',
        ),
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'ابحث بالاسم أو اليوزر',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    filled: true,
                    fillColor: const Color(0xFF102038),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _search = value.trim();
                    });
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      final filter = _filters[index];
                      final selected = _filter == filter;
                      return ChoiceChip(
                        label: Text(filter),
                        selected: selected,
                        onSelected: (_) {
                          setState(() {
                            _filter = filter;
                          });
                        },
                        selectedColor: const Color(0xFF38BDF8),
                        backgroundColor: const Color(0xFF102038),
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : Colors.white70,
                        ),
                      );
                    },
                    separatorBuilder: (_, separatorIndex) =>
                        const SizedBox(width: 8),
                    itemCount: _filters.length,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filteredPlayers.isEmpty
                ? const Center(
                    child: Text(
                      'لا يوجد لاعبون مطابقون حالياً',
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: filteredPlayers.length,
                    itemBuilder: (context, index) {
                      final player = filteredPlayers[index];
                      final alreadySelected = widget.selectedPlayerIds
                              .contains(player.player.id) &&
                          widget.currentPlayerId != player.player.id;
                      final affordable =
                          player.value.currentPrice <= widget.availableBudget;
                      final canSelect = !alreadySelected && affordable;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF102038),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          leading: TierBadgeWidget(tier: player.value.tier),
                          title: Text(
                            player.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                _MetaChip(
                                  label: player.positionCode,
                                  color: const Color(0xFF1D4ED8),
                                ),
                                _MetaChip(
                                  label: '${player.value.currentPrice}M',
                                  color: const Color(0xFF22C55E),
                                ),
                                _MetaChip(
                                  label: '${player.value.totalFantasyPoints} pts',
                                  color: const Color(0xFFF59E0B),
                                ),
                              ],
                            ),
                          ),
                          trailing: FilledButton(
                            onPressed: canSelect
                                ? () => Get.back(result: player)
                                : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF38BDF8),
                              disabledBackgroundColor:
                                  Colors.white.withValues(alpha: 0.12),
                            ),
                            child: Text(
                              alreadySelected
                                  ? 'مختار'
                                  : affordable
                                      ? 'اختيار'
                                      : 'غالي',
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final Color color;

  const _MetaChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}
