import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_text_styles.dart';
import 'identity_preset.dart';
import 'identity_preset_catalog.dart';
import 'identity_preset_mark.dart';
import 'identity_visual.dart';

/// Full-screen Arabic picker for built-in team and tournament identities.
class IdentityPresetPickerScreen extends StatefulWidget {
  const IdentityPresetPickerScreen({
    super.key,
    required this.scope,
    this.initialReference,
    this.previewTitle,
  });

  final IdentityPresetScope scope;
  final String? initialReference;
  final String? previewTitle;

  static Future<IdentityPresetSelection?> show(
    BuildContext context, {
    required IdentityPresetScope scope,
    String? initialReference,
    String? previewTitle,
  }) {
    return Navigator.of(context).push<IdentityPresetSelection>(
      MaterialPageRoute<IdentityPresetSelection>(
        builder: (_) => IdentityPresetPickerScreen(
          scope: scope,
          initialReference: initialReference,
          previewTitle: previewTitle,
        ),
      ),
    );
  }

  @override
  State<IdentityPresetPickerScreen> createState() =>
      _IdentityPresetPickerScreenState();
}

class _IdentityPresetPickerScreenState extends State<IdentityPresetPickerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String? _selectedReference;

  bool get _isTeam => widget.scope == IdentityPresetScope.team;

  @override
  void initState() {
    super.initState();
    final initialPreset = IdentityPresetCatalog.findByReference(
      widget.initialReference,
    );
    final isAllowed =
        initialPreset != null &&
        IdentityPresetCatalog.forScope(widget.scope).contains(initialPreset);
    _selectedReference = isAllowed ? initialPreset.value : null;
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: initialPreset?.family == IdentityPresetFamily.teamPennant
          ? 1
          : 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _isTeam ? 'اختيار هوية الفريق' : 'اختيار رمز البطولة';
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(title),
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
        ),
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildPreview(),
              if (_isTeam) _buildTeamTabs(),
              Expanded(
                child: _isTeam
                    ? TabBarView(
                        controller: _tabController,
                        children: <Widget>[
                          _buildGrid(IdentityPresetCatalog.teamBadges),
                          _buildGrid(IdentityPresetCatalog.teamPennants),
                        ],
                      )
                    : _buildGrid(IdentityPresetCatalog.tournamentEmblems),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _buildActionBar(context),
      ),
    );
  }

  Widget _buildPreview() {
    final selected = IdentityPresetCatalog.findByReference(_selectedReference);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.pagePadding,
        AppDimensions.space2,
        AppDimensions.pagePadding,
        AppDimensions.space3,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.space3),
          child: Row(
            children: <Widget>[
              _buildPreviewMark(selected),
              const SizedBox(width: AppDimensions.space3),
              Expanded(child: _buildPreviewCopy(selected)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewMark(IdentityPreset? selected) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutQuart,
      switchOutCurve: Curves.easeOutQuart,
      child: selected == null
          ? const IdentityVisual(
              key: ValueKey<String>('identity-preview-empty'),
              size: 88,
              semanticLabel: 'معاينة الهوية الافتراضية',
            )
          : IdentityPresetMark(
              key: ValueKey<String>(selected.value),
              preset: selected,
              size: 88,
              semanticLabel: 'معاينة ${selected.nameAr}',
            ),
    );
  }

  Widget _buildPreviewCopy(IdentityPreset? selected) {
    final entityTitle = widget.previewTitle?.trim();
    final visibleTitle = entityTitle == null || entityTitle.isEmpty
        ? (_isTeam ? 'اسم الفريق' : 'اسم البطولة')
        : entityTitle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          visibleTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.headlineSmall,
        ),
        const SizedBox(height: AppDimensions.space1),
        Text(
          selected?.nameAr ?? 'اختر شكلاً يعبر عن هويتك',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodySmall.copyWith(
            color: selected == null
                ? AppColors.textSecondary
                : AppColors.actionLight,
          ),
        ),
      ],
    );
  }

  Widget _buildTeamTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.pagePadding,
      ),
      child: TabBar(
        controller: _tabController,
        tabs: const <Widget>[
          Tab(text: 'شعارات'),
          Tab(text: 'رايات'),
        ],
      ),
    );
  }

  Widget _buildGrid(List<IdentityPreset> presets) {
    return GridView.builder(
      key: PageStorageKey<String>('identity-grid-${presets.first.family.name}'),
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.pagePadding,
        AppDimensions.space3,
        AppDimensions.pagePadding,
        AppDimensions.space4,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: AppDimensions.space2,
        mainAxisSpacing: AppDimensions.space2,
        childAspectRatio: 0.86,
      ),
      itemCount: presets.length,
      itemBuilder: (context, index) => _buildPresetTile(presets[index]),
    );
  }

  Widget _buildPresetTile(IdentityPreset preset) {
    final isSelected = _selectedReference == preset.value;
    return Semantics(
      button: true,
      selected: isSelected,
      label: 'اختيار ${preset.nameAr}',
      child: Material(
        key: ValueKey<String>('identity-preset-${preset.value}'),
        color: isSelected ? AppColors.actionSurface : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          side: BorderSide(
            color: isSelected
                ? AppColors.actionPrimary
                : AppColors.surfaceBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() => _selectedReference = preset.value),
          child: Stack(
            children: <Widget>[
              _buildPresetContent(preset, isSelected),
              if (isSelected) _buildSelectedIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetContent(IdentityPreset preset, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.space2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.contain,
                child: IdentityPresetMark(preset: preset, size: 64),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.space1),
          Text(
            preset.nameAr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelMedium.copyWith(
              color: isSelected
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedIndicator() {
    return const PositionedDirectional(
      top: AppDimensions.space1,
      end: AppDimensions.space1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.actionPrimary,
          shape: BoxShape.circle,
        ),
        child: Padding(
          padding: EdgeInsets.all(3),
          child: Icon(
            Icons.check_rounded,
            size: 14,
            color: AppColors.textOnPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildActionBar(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surfaceSunken,
        border: Border(top: BorderSide(color: AppColors.surfaceBorder)),
      ),
      child: SafeArea(
        minimum: const EdgeInsets.all(AppDimensions.pagePadding),
        child: Row(
          children: <Widget>[
            TextButton(
              key: const ValueKey<String>('identity-clear-action'),
              onPressed: () => Navigator.of(
                context,
              ).pop(const IdentityPresetSelection.clear()),
              child: const Text('بدون شعار'),
            ),
            const SizedBox(width: AppDimensions.space2),
            Expanded(
              child: FilledButton.icon(
                key: const ValueKey<String>('identity-use-action'),
                onPressed: _selectedReference == null
                    ? null
                    : () => Navigator.of(
                        context,
                      ).pop(IdentityPresetSelection.use(_selectedReference!)),
                icon: const Icon(Icons.check_rounded),
                label: const Text('استخدم الهوية'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
