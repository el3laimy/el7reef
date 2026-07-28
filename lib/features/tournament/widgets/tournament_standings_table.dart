import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../domain/entities/group_standing_snapshot.dart';

class TournamentStandingsTable extends StatefulWidget {
  static const double wideBreakpoint = 520;

  final List<GroupStandingEntry> entries;
  final Set<String> qualifierParticipantIds;
  final bool qualificationIsOfficial;

  const TournamentStandingsTable({
    super.key,
    required this.entries,
    required this.qualifierParticipantIds,
    required this.qualificationIsOfficial,
  });

  @override
  State<TournamentStandingsTable> createState() =>
      _TournamentStandingsTableState();
}

class _TournamentStandingsTableState extends State<TournamentStandingsTable> {
  final Set<String> _expandedParticipantIds = <String>{};

  @override
  void didUpdateWidget(covariant TournamentStandingsTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentIds = widget.entries
        .map((entry) => entry.participantId)
        .toSet();
    _expandedParticipantIds.removeWhere(
      (participantId) => !currentIds.contains(participantId),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) {
      return Container(
        key: const ValueKey('standings-table-empty'),
        width: double.infinity,
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceSunken,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Text(
          'سيظهر ترتيب الفرق بعد تسجيل أول نتيجة.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondaryTinted,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= TournamentStandingsTable.wideBreakpoint) {
          return _WideStandingsTable(
            entries: widget.entries,
            qualifiers: widget.qualifierParticipantIds,
            qualificationIsOfficial: widget.qualificationIsOfficial,
          );
        }
        return _CompactStandingsTable(
          entries: widget.entries,
          qualifiers: widget.qualifierParticipantIds,
          qualificationIsOfficial: widget.qualificationIsOfficial,
          expandedParticipantIds: _expandedParticipantIds,
          onToggle: (participantId) {
            setState(() {
              if (!_expandedParticipantIds.remove(participantId)) {
                _expandedParticipantIds.add(participantId);
              }
            });
          },
        );
      },
    );
  }
}

class _CompactStandingsTable extends StatelessWidget {
  final List<GroupStandingEntry> entries;
  final Set<String> qualifiers;
  final bool qualificationIsOfficial;
  final Set<String> expandedParticipantIds;
  final ValueChanged<String> onToggle;

  const _CompactStandingsTable({
    required this.entries,
    required this.qualifiers,
    required this.qualificationIsOfficial,
    required this.expandedParticipantIds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('standings-table-compact'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.surfaceBorderStrong),
      ),
      child: Column(
        children: [
          const _CompactTableHeader(),
          for (var index = 0; index < entries.length; index++) ...[
            _CompactStandingRow(
              entry: entries[index],
              isQualified: qualifiers.contains(entries[index].participantId),
              qualificationIsOfficial: qualificationIsOfficial,
              isExpanded: expandedParticipantIds.contains(
                entries[index].participantId,
              ),
              onTap: () => onToggle(entries[index].participantId),
            ),
            if (index != entries.length - 1)
              const Divider(height: 1, color: AppColors.surfaceBorder),
          ],
        ],
      ),
    );
  }
}

class _CompactTableHeader extends StatelessWidget {
  const _CompactTableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceRaised,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.sm,
        vertical: AppDimensions.sm,
      ),
      child: const Row(
        children: [
          _HeaderCell(label: '#', width: 32),
          SizedBox(width: AppDimensions.sm),
          Expanded(child: _HeaderCell(label: 'الفريق')),
          _HeaderCell(label: 'لعب', width: 38),
          _HeaderCell(label: 'فرق', width: 38),
          _HeaderCell(label: 'نقاط', width: 44, emphasized: true),
        ],
      ),
    );
  }
}

class _CompactStandingRow extends StatelessWidget {
  final GroupStandingEntry entry;
  final bool isQualified;
  final bool qualificationIsOfficial;
  final bool isExpanded;
  final VoidCallback onTap;

  const _CompactStandingRow({
    required this.entry,
    required this.isQualified,
    required this.qualificationIsOfficial,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final qualificationLabel = qualificationIsOfficial
        ? 'متأهل رسميًا'
        : 'داخل مراكز التأهل';
    final semanticLabel = StringBuffer()
      ..write('المركز ${entry.rank}، ${entry.displayName}، ')
      ..write('لعب ${entry.played}، ${_goalDifferenceLabel(entry)}، ')
      ..write('${entry.points} نقطة')
      ..write(isQualified ? '، $qualificationLabel' : '');

    return Semantics(
      button: true,
      expanded: isExpanded,
      label: semanticLabel.toString(),
      hint: isExpanded ? 'اضغط لإخفاء التفاصيل' : 'اضغط لعرض التفاصيل',
      child: InkWell(
        key: ValueKey('standing-row-${entry.participantId}'),
        onTap: onTap,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutQuart,
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.sm,
              vertical: AppDimensions.sm,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _NumericCell(
                      value: '${entry.rank}',
                      width: 32,
                      color: AppColors.textSecondaryTinted,
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.titleMedium.copyWith(
                              color: AppColors.textPrimaryTinted,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (isQualified)
                            _QualificationText(
                              isOfficial: qualificationIsOfficial,
                            ),
                        ],
                      ),
                    ),
                    _NumericCell(value: '${entry.played}', width: 38),
                    _NumericCell(
                      value: _signedNumber(entry.goalDifference),
                      width: 38,
                    ),
                    _NumericCell(
                      value: '${entry.points}',
                      width: 44,
                      color: AppColors.textPrimary,
                      emphasized: true,
                    ),
                  ],
                ),
                if (isExpanded) ...[
                  const SizedBox(height: AppDimensions.sm),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppDimensions.sm),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusSm,
                      ),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: Wrap(
                      spacing: AppDimensions.md,
                      runSpacing: AppDimensions.sm,
                      children: [
                        _DetailStat(label: 'فاز', value: entry.wins),
                        _DetailStat(label: 'تعادل', value: entry.draws),
                        _DetailStat(label: 'خسر', value: entry.losses),
                        _DetailStat(label: 'له', value: entry.goalsFor),
                        _DetailStat(label: 'عليه', value: entry.goalsAgainst),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WideStandingsTable extends StatelessWidget {
  final List<GroupStandingEntry> entries;
  final Set<String> qualifiers;
  final bool qualificationIsOfficial;

  const _WideStandingsTable({
    required this.entries,
    required this.qualifiers,
    required this.qualificationIsOfficial,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('standings-table-wide'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.surfaceBorderStrong),
      ),
      child: Table(
        columnWidths: const <int, TableColumnWidth>{
          0: FixedColumnWidth(40),
          1: FlexColumnWidth(3.2),
          2: FlexColumnWidth(),
          3: FlexColumnWidth(),
          4: FlexColumnWidth(),
          5: FlexColumnWidth(),
          6: FlexColumnWidth(),
          7: FlexColumnWidth(),
          8: FlexColumnWidth(),
          9: FlexColumnWidth(1.2),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        border: const TableBorder(
          horizontalInside: BorderSide(color: AppColors.surfaceBorder),
        ),
        children: [
          TableRow(
            decoration: const BoxDecoration(color: AppColors.surfaceRaised),
            children: const [
              _WideHeaderCell('#'),
              _WideHeaderCell('الفريق', textAlign: TextAlign.start),
              _WideHeaderCell('لعب'),
              _WideHeaderCell('فاز'),
              _WideHeaderCell('تعادل'),
              _WideHeaderCell('خسر'),
              _WideHeaderCell('له'),
              _WideHeaderCell('عليه'),
              _WideHeaderCell('فرق'),
              _WideHeaderCell('نقاط', emphasized: true),
            ],
          ),
          for (final entry in entries)
            _wideEntryRow(
              entry,
              isQualified: qualifiers.contains(entry.participantId),
            ),
        ],
      ),
    );
  }

  TableRow _wideEntryRow(
    GroupStandingEntry entry, {
    required bool isQualified,
  }) {
    final qualificationLabel = qualificationIsOfficial
        ? 'متأهل رسميًا'
        : 'داخل مراكز التأهل';
    return TableRow(
      decoration: BoxDecoration(
        color: isQualified
            ? AppColors.tactical.withValues(alpha: 0.045)
            : Colors.transparent,
      ),
      children: [
        _WideValueCell('${entry.rank}'),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.sm,
            vertical: AppDimensions.sm,
          ),
          child: Semantics(
            label: isQualified
                ? '${entry.displayName}، $qualificationLabel'
                : entry.displayName,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.textPrimaryTinted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (isQualified)
                  _QualificationText(isOfficial: qualificationIsOfficial),
              ],
            ),
          ),
        ),
        _WideValueCell('${entry.played}'),
        _WideValueCell('${entry.wins}'),
        _WideValueCell('${entry.draws}'),
        _WideValueCell('${entry.losses}'),
        _WideValueCell('${entry.goalsFor}'),
        _WideValueCell('${entry.goalsAgainst}'),
        _WideValueCell(_signedNumber(entry.goalDifference)),
        _WideValueCell(
          '${entry.points}',
          color: AppColors.textPrimary,
          emphasized: true,
        ),
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final double? width;
  final bool emphasized;

  const _HeaderCell({required this.label, this.width, this.emphasized = false});

  @override
  Widget build(BuildContext context) {
    final child = Text(
      label,
      textAlign: TextAlign.center,
      style: AppTextStyles.labelMedium.copyWith(
        color: emphasized
            ? AppColors.textPrimary
            : AppColors.textSecondaryTinted,
        fontWeight: FontWeight.w800,
      ),
    );
    return width == null ? child : SizedBox(width: width, child: child);
  }
}

class _NumericCell extends StatelessWidget {
  final String value;
  final double width;
  final Color color;
  final bool emphasized;

  const _NumericCell({
    required this.value,
    required this.width,
    this.color = AppColors.textPrimaryTinted,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        value,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        style: AppTextStyles.labelLarge.copyWith(
          color: color,
          fontWeight: emphasized ? FontWeight.w900 : FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _WideHeaderCell extends StatelessWidget {
  final String label;
  final bool emphasized;
  final TextAlign textAlign;

  const _WideHeaderCell(
    this.label, {
    this.emphasized = false,
    this.textAlign = TextAlign.center,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.xs,
        vertical: AppDimensions.sm,
      ),
      child: Text(
        label,
        textAlign: textAlign,
        style: AppTextStyles.labelMedium.copyWith(
          color: emphasized
              ? AppColors.textPrimary
              : AppColors.textSecondaryTinted,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _WideValueCell extends StatelessWidget {
  final String value;
  final Color color;
  final bool emphasized;

  const _WideValueCell(
    this.value, {
    this.color = AppColors.textPrimaryTinted,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
      child: Text(
        value,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        style: AppTextStyles.labelLarge.copyWith(
          color: color,
          fontWeight: emphasized ? FontWeight.w900 : FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  final String label;
  final int value;

  const _DetailStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondaryTinted,
          ),
        ),
        const SizedBox(width: AppDimensions.xs),
        Text(
          '$value',
          textDirection: TextDirection.ltr,
          style: AppTextStyles.labelLarge.copyWith(
            color: AppColors.textPrimaryTinted,
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _QualificationText extends StatelessWidget {
  final bool isOfficial;

  const _QualificationText({required this.isOfficial});

  @override
  Widget build(BuildContext context) {
    final color = isOfficial ? AppColors.tactical : AppColors.info;
    final style = AppTextStyles.bodySmall.copyWith(
      color: color,
      fontWeight: FontWeight.w700,
    );
    if (!isOfficial) {
      return Text('داخل مراكز التأهل', style: style);
    }
    return Semantics(
      label: 'متأهل رسميًا',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('متأهل', style: style),
            Text(' رسميًا', style: style),
          ],
        ),
      ),
    );
  }
}

String _signedNumber(int value) => value > 0 ? '+$value' : '$value';

String _goalDifferenceLabel(GroupStandingEntry entry) =>
    'فرق أهداف ${_signedNumber(entry.goalDifference)}';
