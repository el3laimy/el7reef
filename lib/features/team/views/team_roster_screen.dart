import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/constants/feature_flags.dart';
import '../../../core/enums/team_member_availability.dart';
import '../../../core/enums/team_membership_role.dart';
import '../../../core/enums/team_membership_status.dart';
import '../../../core/widgets/el7reef_button.dart';
import '../../../core/widgets/glassmorphic_container.dart';
import '../../../domain/entities/player.dart';
import '../../../domain/entities/team.dart';
import '../../../domain/entities/team_formation_template.dart';
import '../../../domain/entities/team_roster_snapshot.dart';
import '../controllers/team_roster_controller.dart';

class TeamRosterScreen extends GetView<TeamRosterController> {
  const TeamRosterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('قائمة الفريق')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Obx(() {
          if (controller.isLoading.value && controller.team.value == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final team = controller.team.value;
          if (team == null) {
            return _buildErrorState();
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: controller.loadTeamRoster,
            child: ListView(
              padding: const EdgeInsets.all(AppDimensions.pagePadding),
              children: [
                _buildHeader(team),
                const SizedBox(height: AppDimensions.md),
                _buildRosterActions(context),
                const SizedBox(height: AppDimensions.lg),
                _buildFormationWorkspace(context),
                const SizedBox(height: AppDimensions.lg),
                _buildSection(
                  title: 'الأساسيون',
                  status: TeamMembershipStatus.starter,
                  icon: Icons.sports_soccer,
                  accentColor: AppColors.primary,
                ),
                const SizedBox(height: AppDimensions.md),
                _buildSection(
                  title: 'الاحتياط',
                  status: TeamMembershipStatus.bench,
                  icon: Icons.airline_seat_recline_extra,
                  accentColor: AppColors.secondary,
                ),
                const SizedBox(height: AppDimensions.md),
                _buildSection(
                  title: 'غير النشطين',
                  status: TeamMembershipStatus.inactive,
                  icon: Icons.pause_circle_outline,
                  accentColor: AppColors.textMuted,
                ),
                const SizedBox(height: AppDimensions.xxl),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.group_off_rounded,
              size: 72,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppDimensions.md),
            Text(
              controller.errorMessage.value.isEmpty
                  ? 'تعذر تحميل قائمة الفريق.'
                  : controller.errorMessage.value,
              style: AppTextStyles.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.md),
            El7reefButton(
              text: 'إعادة المحاولة',
              icon: Icons.refresh,
              width: 200,
              onPressed: controller.loadTeamRoster,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Team team) {
    return GlassmorphicContainer(
      borderRadius: AppDimensions.radiusXl,
      padding: const EdgeInsets.all(AppDimensions.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                ),
                alignment: Alignment.center,
                child: Text(
                  team.name.isNotEmpty ? team.name[0] : '?',
                  style: AppTextStyles.headlineLarge.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(team.name, style: AppTextStyles.headlineMedium),
                    const SizedBox(height: AppDimensions.xs),
                    Text(
                      'إدارة حيّة للقائمة الأساسية والاحتياط والضيوف',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.lg),
          Wrap(
            spacing: AppDimensions.sm,
            runSpacing: AppDimensions.sm,
            children: [
              _buildCountChip(
                label: 'أساسي',
                count: controller.countByStatus(TeamMembershipStatus.starter),
                color: AppColors.primary,
              ),
              _buildCountChip(
                label: 'احتياط',
                count: controller.countByStatus(TeamMembershipStatus.bench),
                color: AppColors.secondary,
              ),
              _buildCountChip(
                label: 'غير نشط',
                count: controller.countByStatus(TeamMembershipStatus.inactive),
                color: AppColors.textMuted,
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.08);
  }

  Widget _buildCountChip({
    required String label,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$label: $count',
        style: AppTextStyles.labelMedium.copyWith(color: color),
      ),
    );
  }

  Widget _buildRosterActions(BuildContext context) {
    if (!controller.canManageRoster) {
      return GlassmorphicContainer(
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Text(
          'يمكنك مشاهدة القائمة حالياً، لكن إدارة التشكيلة متاحة فقط لمالك الفريق أو نوابه.',
          style: AppTextStyles.bodyMedium,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('إدارة القائمة', style: AppTextStyles.titleLarge),
        const SizedBox(height: AppDimensions.sm),
        Row(
          children: [
            Expanded(
              child: El7reefButton(
                text: 'إضافة لاعب',
                icon: Icons.person_add_alt_1,
                onPressed: () => _showRegisteredPlayerSheet(context),
              ),
            ),
            if (FeatureFlags.guestIdentityEnabled) ...[
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: El7reefButton(
                  text: 'إضافة ضيف',
                  icon: Icons.group_add_rounded,
                  isOutlined: true,
                  onPressed: () => _showGuestPlayerSheet(context),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppDimensions.sm),
        SizedBox(
          width: double.infinity,
          child: El7reefButton(
            text: 'مشاركة رابط الانضمام للفريق',
            icon: Icons.share_rounded,
            isOutlined: true,
            onPressed: controller.shareTeamInviteLink,
          ),
        ),
      ],
    );
  }

  Widget _buildFormationWorkspace(BuildContext context) {
    return GlassmorphicContainer(
      borderRadius: AppDimensions.radiusXl,
      padding: const EdgeInsets.all(AppDimensions.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.dashboard_customize_rounded,
                  color: AppColors.primary),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: Text('القوالب والنسخ الجاهزة',
                    style: AppTextStyles.headlineSmall),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.xs),
          Text(
            'الوضع الحالي: ${controller.currentFormationSummary}',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: AppDimensions.md),
          if (controller.canManageRoster)
            Row(
              children: [
                Expanded(
                  child: El7reefButton(
                    text: 'حفظ كقالب',
                    icon: Icons.save_alt_rounded,
                    onPressed: () => _showTemplateSheet(context),
                  ),
                ),
                const SizedBox(width: AppDimensions.sm),
                Expanded(
                  child: El7reefButton(
                    text: 'إنشاء نسخة',
                    icon: Icons.content_copy_rounded,
                    isOutlined: true,
                    onPressed: () => _showSnapshotSheet(context),
                  ),
                ),
              ],
            ),
          const SizedBox(height: AppDimensions.lg),
          Text('القوالب المحفوظة', style: AppTextStyles.titleLarge),
          const SizedBox(height: AppDimensions.sm),
          Obx(() {
            if (controller.formationTemplates.isEmpty) {
              return Text(
                'لا توجد قوالب محفوظة بعد. احفظ التشكيلة الحالية لتعيد استخدامها لاحقًا.',
                style: AppTextStyles.bodySmall,
              );
            }

            return Column(
              children: controller.formationTemplates
                  .map(_buildTemplateCard)
                  .toList(growable: false),
            );
          }),
          const SizedBox(height: AppDimensions.lg),
          Text('النسخ الجاهزة', style: AppTextStyles.titleLarge),
          const SizedBox(height: AppDimensions.sm),
          Obx(() {
            if (controller.rosterSnapshots.isEmpty) {
              return Text(
                'لم يتم إنشاء أي نسخة جاهزة للمباراة بعد.',
                style: AppTextStyles.bodySmall,
              );
            }

            return Column(
              children: controller.rosterSnapshots
                  .map(_buildSnapshotCard)
                  .toList(growable: false),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTemplateCard(TeamFormationTemplate template) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(template.name, style: AppTextStyles.titleLarge),
                    const SizedBox(height: 2),
                    Text(template.summaryLabel, style: AppTextStyles.bodySmall),
                    const SizedBox(height: 2),
                    Text(
                      'آخر تحديث: ${_formatDate(template.updatedAt)}',
                      style: AppTextStyles.labelSmall,
                    ),
                  ],
                ),
              ),
              if (controller.canManageRoster)
                PopupMenuButton<_TemplateAction>(
                  color: AppColors.surfaceLight,
                  onSelected: (action) async {
                    switch (action) {
                      case _TemplateAction.apply:
                        await controller.applyTemplate(template);
                      case _TemplateAction.delete:
                        final confirmed = await Get.dialog<bool>(
                          AlertDialog(
                            title: const Text('حذف القالب'),
                            content: Text(
                              'هل تريد حذف القالب ${template.name}؟',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Get.back(result: false),
                                child: const Text('إلغاء'),
                              ),
                              FilledButton(
                                onPressed: () => Get.back(result: true),
                                child: const Text('حذف'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await controller.deleteTemplate(template);
                        }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: _TemplateAction.apply,
                      child: Text('تطبيق القالب'),
                    ),
                    PopupMenuItem(
                      value: _TemplateAction.delete,
                      child: Text('حذف القالب'),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          Wrap(
            spacing: AppDimensions.xs,
            runSpacing: AppDimensions.xs,
            children: [
              _buildTag('أساسي ${template.starterCount}', AppColors.primary),
              _buildTag('احتياط ${template.benchCount}', AppColors.secondary),
              _buildTag('غير نشط ${template.inactiveCount}', AppColors.textMuted),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSnapshotCard(TeamRosterSnapshot snapshot) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(snapshot.label, style: AppTextStyles.titleLarge),
          const SizedBox(height: 2),
          Text(snapshot.summaryLabel, style: AppTextStyles.bodySmall),
          const SizedBox(height: 2),
          Text(
            'تم الإنشاء: ${_formatDate(snapshot.createdAt)}',
            style: AppTextStyles.labelSmall,
          ),
          if ((snapshot.sourceTemplateId ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'مشتقة من قالب محفوظ',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.primaryLight,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required TeamMembershipStatus status,
    required IconData icon,
    required Color accentColor,
  }) {
    final members = controller.membersByStatus(status);
    return GlassmorphicContainer(
      borderRadius: AppDimensions.radiusXl,
      padding: const EdgeInsets.all(AppDimensions.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor),
              const SizedBox(width: AppDimensions.sm),
              Text(title, style: AppTextStyles.headlineSmall),
              const Spacer(),
              Text(
                '${members.length}',
                style: AppTextStyles.titleMedium.copyWith(color: accentColor),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          if (members.isEmpty)
            Text(
              'لا يوجد عناصر في هذا القسم حالياً.',
              style: AppTextStyles.bodySmall,
            )
          else
            ...members.map(_buildMemberCard),
        ],
      ),
    );
  }

  Widget _buildMemberCard(TeamRosterMemberViewData entry) {
    final membership = entry.membership;
    final accentColor = entry.isGuest ? AppColors.accent : AppColors.primary;
    final canShowActions = controller.canManageRoster;

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withValues(alpha: 0.18),
              border: Border.all(color: accentColor.withValues(alpha: 0.4)),
            ),
            alignment: Alignment.center,
            child: Text(
              entry.displayName.isNotEmpty
                  ? entry.displayName.characters.first
                  : '?',
              style: AppTextStyles.titleLarge.copyWith(color: accentColor),
            ),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.displayName, style: AppTextStyles.titleLarge),
                if ((entry.secondaryText ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.secondaryText!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: entry.isGuest
                          ? AppColors.accentLight
                          : AppColors.primaryLight,
                    ),
                  ),
                ],
                if ((entry.position ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'المركز: ${entry.position}',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
                const SizedBox(height: AppDimensions.sm),
                Wrap(
                  spacing: AppDimensions.xs,
                  runSpacing: AppDimensions.xs,
                  children: [
                    _buildTag(
                      entry.isGuest ? 'ضيف' : 'مسجل',
                      entry.isGuest ? AppColors.accent : AppColors.primary,
                    ),
                    _buildTag(
                      _roleLabel(membership.role),
                      membership.role == TeamMembershipRole.viceCaptain
                          ? AppColors.secondary
                          : AppColors.textSecondary,
                    ),
                    _buildTag(
                      _availabilityLabel(membership.availability),
                      _availabilityColor(membership.availability),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (canShowActions)
            PopupMenuButton<_RosterAction>(
              icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
              color: AppColors.surfaceLight,
              onSelected: (action) => _handleAction(action, entry),
              itemBuilder: (_) => _buildActionItems(entry),
            ),
        ],
      ),
    );
  }

  Widget _buildTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.sm,
        vertical: AppDimensions.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(color: color),
      ),
    );
  }

  List<PopupMenuEntry<_RosterAction>> _buildActionItems(
    TeamRosterMemberViewData entry,
  ) {
    final membership = entry.membership;
    final items = <PopupMenuEntry<_RosterAction>>[];

    if (membership.status != TeamMembershipStatus.starter) {
      items.add(const PopupMenuItem(
        value: _RosterAction.moveToStarter,
        child: Text('نقله إلى الأساسيين'),
      ));
    }
    if (membership.status != TeamMembershipStatus.bench) {
      items.add(const PopupMenuItem(
        value: _RosterAction.moveToBench,
        child: Text('نقله إلى الاحتياط'),
      ));
    }
    if (membership.status != TeamMembershipStatus.inactive) {
      items.add(const PopupMenuItem(
        value: _RosterAction.makeInactive,
        child: Text('جعله غير نشط'),
      ));
    }

    if (!entry.isGuest && membership.role != TeamMembershipRole.owner) {
      if (membership.role != TeamMembershipRole.viceCaptain) {
        items.add(const PopupMenuItem(
          value: _RosterAction.promoteViceCaptain,
          child: Text('ترقية إلى نائب قائد'),
        ));
      } else {
        items.add(const PopupMenuItem(
          value: _RosterAction.demoteToPlayer,
          child: Text('إلغاء منصب نائب القائد'),
        ));
      }
    }

    if (membership.availability != TeamMemberAvailability.available) {
      items.add(const PopupMenuItem(
        value: _RosterAction.markAvailable,
        child: Text('متاح'),
      ));
    }
    if (membership.availability != TeamMemberAvailability.unavailable) {
      items.add(const PopupMenuItem(
        value: _RosterAction.markUnavailable,
        child: Text('غير متاح'),
      ));
    }
    if (membership.availability != TeamMemberAvailability.injured) {
      items.add(const PopupMenuItem(
        value: _RosterAction.markInjured,
        child: Text('مصاب'),
      ));
    }

    if (membership.role != TeamMembershipRole.owner) {
      items.add(const PopupMenuDivider());
      items.add(const PopupMenuItem(
        value: _RosterAction.remove,
        child: Text('إزالة من القائمة'),
      ));
    }

    if (entry.isGuest) {
      items.add(const PopupMenuDivider());
      items.add(const PopupMenuItem(
        value: _RosterAction.shareGuestClaim,
        child: Text('إرسال رابط استلام الملف'),
      ));
    }

    return items;
  }

  Future<void> _handleAction(
    _RosterAction action,
    TeamRosterMemberViewData entry,
  ) async {
    final membership = entry.membership;
    switch (action) {
      case _RosterAction.moveToStarter:
        await controller.changeMemberStatus(
          membership,
          TeamMembershipStatus.starter,
        );
      case _RosterAction.moveToBench:
        await controller.changeMemberStatus(
          membership,
          TeamMembershipStatus.bench,
        );
      case _RosterAction.makeInactive:
        await controller.changeMemberStatus(
          membership,
          TeamMembershipStatus.inactive,
        );
      case _RosterAction.promoteViceCaptain:
        await controller.changeRole(
          membership,
          TeamMembershipRole.viceCaptain,
        );
      case _RosterAction.demoteToPlayer:
        await controller.changeRole(
          membership,
          TeamMembershipRole.player,
        );
      case _RosterAction.markAvailable:
        await controller.changeAvailability(
          membership,
          TeamMemberAvailability.available,
        );
      case _RosterAction.markUnavailable:
        await controller.changeAvailability(
          membership,
          TeamMemberAvailability.unavailable,
        );
      case _RosterAction.markInjured:
        await controller.changeAvailability(
          membership,
          TeamMemberAvailability.injured,
        );
      case _RosterAction.remove:
        final confirmed = await Get.dialog<bool>(
          AlertDialog(
            title: const Text('إزالة من القائمة'),
            content: Text('هل تريد إزالة ${entry.displayName} من القائمة النشطة؟'),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Get.back(result: true),
                child: const Text('إزالة'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await controller.removeMembership(membership);
        }
      case _RosterAction.shareGuestClaim:
        if (membership.guestPlayerId != null) {
          await controller.shareGuestPlayerClaimLink(membership.guestPlayerId!);
        }
    }
  }

  Future<void> _showRegisteredPlayerSheet(BuildContext context) async {
    controller.clearPlayerSearch();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusXl),
        ),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: AppDimensions.lg,
          right: AppDimensions.lg,
          top: AppDimensions.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppDimensions.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('إضافة لاعب مسجل', style: AppTextStyles.headlineMedium),
            const SizedBox(height: AppDimensions.md),
            TextField(
              controller: controller.registeredSearchController,
              decoration: const InputDecoration(
                labelText: 'ابحث بالاسم أو @username',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: AppDimensions.md),
            SizedBox(
              height: 320,
              child: Obx(() {
                if (controller.isSearchingPlayers.value) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                if (controller.registeredSearchController.text.trim().isEmpty) {
                  return Center(
                    child: Text(
                      'ابدأ بكتابة اسم اللاعب أو الـ username للبحث.',
                      style: AppTextStyles.bodyMedium,
                    ),
                  );
                }

                if (controller.playerSearchResults.isEmpty) {
                  return Center(
                    child: Text(
                      'لا يوجد لاعبون مطابقون أو أنهم موجودون بالفعل داخل القائمة.',
                      style: AppTextStyles.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: controller.playerSearchResults.length,
                  separatorBuilder: (_, separatorIndex) =>
                      const SizedBox(height: AppDimensions.sm),
                  itemBuilder: (_, index) {
                    final player = controller.playerSearchResults[index];
                    return _buildSearchResultTile(player);
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultTile(Player player) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primarySurface,
            child: Text(
              player.name.isNotEmpty ? player.name[0] : '?',
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(player.name, style: AppTextStyles.titleLarge),
                if (player.hasUsername)
                  Text(
                    player.displayUsername,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primaryLight,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: controller.isSubmitting.value
                ? null
                : () => controller.addRegisteredPlayer(player),
            icon: const Icon(Icons.add_circle, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Future<void> _showGuestPlayerSheet(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    var selectedStatus = TeamMembershipStatus.bench;
    controller.clearGuestForm();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusXl),
        ),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: AppDimensions.lg,
            right: AppDimensions.lg,
            top: AppDimensions.lg,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppDimensions.lg,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('إضافة لاعب ضيف', style: AppTextStyles.headlineMedium),
                const SizedBox(height: AppDimensions.md),
                TextFormField(
                  controller: controller.guestNameController,
                  validator: (value) =>
                      value == null || value.trim().isEmpty
                          ? 'اسم اللاعب مطلوب'
                          : null,
                  decoration: const InputDecoration(
                    labelText: 'اسم اللاعب',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: AppDimensions.sm),
                TextFormField(
                  controller: controller.guestPositionController,
                  decoration: const InputDecoration(
                    labelText: 'المركز',
                    prefixIcon: Icon(Icons.sports_soccer),
                  ),
                ),
                const SizedBox(height: AppDimensions.sm),
                TextFormField(
                  controller: controller.guestJerseyController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'رقم التيشيرت (اختياري)',
                    prefixIcon: Icon(Icons.confirmation_number_outlined),
                  ),
                ),
                const SizedBox(height: AppDimensions.md),
                Text('بداية اللاعب داخل القائمة', style: AppTextStyles.titleMedium),
                const SizedBox(height: AppDimensions.sm),
                Wrap(
                  spacing: AppDimensions.sm,
                  children: [
                    ChoiceChip(
                      label: const Text('احتياط'),
                      selected: selectedStatus == TeamMembershipStatus.bench,
                      onSelected: (_) => setModalState(
                        () => selectedStatus = TeamMembershipStatus.bench,
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('أساسي'),
                      selected: selectedStatus == TeamMembershipStatus.starter,
                      onSelected: (_) => setModalState(
                        () => selectedStatus = TeamMembershipStatus.starter,
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('غير نشط'),
                      selected:
                          selectedStatus == TeamMembershipStatus.inactive,
                      onSelected: (_) => setModalState(
                        () => selectedStatus = TeamMembershipStatus.inactive,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.lg),
                Obx(
                  () => El7reefButton(
                    text: 'إضافة اللاعب',
                    icon: Icons.group_add_rounded,
                    isLoading: controller.isSubmitting.value,
                    onPressed: () {
                      if (!formKey.currentState!.validate()) {
                        return;
                      }
                      controller.createGuestPlayerAndAdd(
                        displayName: controller.guestNameController.text,
                        status: selectedStatus,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    controller.clearGuestForm();
  }

  Future<void> _showTemplateSheet(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    controller.clearTemplateForm();
    controller.templateFormationController.text = controller.currentFormationSummary;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusXl),
        ),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: AppDimensions.lg,
          right: AppDimensions.lg,
          top: AppDimensions.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppDimensions.lg,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('حفظ قالب التشكيلة', style: AppTextStyles.headlineMedium),
              const SizedBox(height: AppDimensions.md),
              TextFormField(
                controller: controller.templateNameController,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'اسم القالب مطلوب'
                    : null,
                decoration: const InputDecoration(
                  labelText: 'اسم القالب',
                  prefixIcon: Icon(Icons.bookmark_border_rounded),
                ),
              ),
              const SizedBox(height: AppDimensions.sm),
              TextFormField(
                controller: controller.templateFormationController,
                decoration: const InputDecoration(
                  labelText: 'وصف الخطة',
                  prefixIcon: Icon(Icons.grid_view_rounded),
                ),
              ),
              const SizedBox(height: AppDimensions.lg),
              Obx(
                () => El7reefButton(
                  text: 'حفظ القالب',
                  icon: Icons.save_alt_rounded,
                  isLoading: controller.isSubmitting.value,
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }
                    final success = await controller.saveFormationTemplate(
                      name: controller.templateNameController.text,
                      formationLabel: controller.templateFormationController.text,
                    );
                    if (success) {
                      Get.back();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    controller.clearTemplateForm();
  }

  Future<void> _showSnapshotSheet(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    controller.clearSnapshotForm();
    controller.snapshotFormationController.text = controller.currentFormationSummary;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusXl),
        ),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: AppDimensions.lg,
          right: AppDimensions.lg,
          top: AppDimensions.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppDimensions.lg,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('إنشاء نسخة جاهزة', style: AppTextStyles.headlineMedium),
              const SizedBox(height: AppDimensions.md),
              TextFormField(
                controller: controller.snapshotLabelController,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'اسم النسخة مطلوب'
                    : null,
                decoration: const InputDecoration(
                  labelText: 'اسم النسخة',
                  prefixIcon: Icon(Icons.content_copy_rounded),
                ),
              ),
              const SizedBox(height: AppDimensions.sm),
              TextFormField(
                controller: controller.snapshotFormationController,
                decoration: const InputDecoration(
                  labelText: 'وصف الخطة',
                  prefixIcon: Icon(Icons.grid_view_rounded),
                ),
              ),
              const SizedBox(height: AppDimensions.lg),
              Obx(
                () => El7reefButton(
                  text: 'إنشاء النسخة',
                  icon: Icons.done_all_rounded,
                  isLoading: controller.isSubmitting.value,
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }
                    final success = await controller.createRosterSnapshot(
                      label: controller.snapshotLabelController.text,
                      formationLabel:
                          controller.snapshotFormationController.text,
                    );
                    if (success) {
                      Get.back();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    controller.clearSnapshotForm();
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month ${value.year} • $hour:$minute';
  }

  String _roleLabel(TeamMembershipRole role) {
    return switch (role) {
      TeamMembershipRole.owner => 'مالك الفريق',
      TeamMembershipRole.viceCaptain => 'نائب قائد',
      TeamMembershipRole.player => 'لاعب',
      TeamMembershipRole.manager => 'مدير فريق',
      TeamMembershipRole.assistantManager => 'مساعد مدير',
    };
  }

  String _availabilityLabel(TeamMemberAvailability availability) {
    return switch (availability) {
      TeamMemberAvailability.available => 'متاح',
      TeamMemberAvailability.unavailable => 'غير متاح',
      TeamMemberAvailability.injured => 'مصاب',
      TeamMemberAvailability.pending => 'قيد التحديد',
    };
  }

  Color _availabilityColor(TeamMemberAvailability availability) {
    return switch (availability) {
      TeamMemberAvailability.available => AppColors.success,
      TeamMemberAvailability.unavailable => AppColors.textMuted,
      TeamMemberAvailability.injured => AppColors.error,
      TeamMemberAvailability.pending => AppColors.warning,
    };
  }
}

enum _RosterAction {
  moveToStarter,
  moveToBench,
  makeInactive,
  promoteViceCaptain,
  demoteToPlayer,
  markAvailable,
  markUnavailable,
  markInjured,
  remove,
  shareGuestClaim,
}

enum _TemplateAction {
  apply,
  delete,
}
