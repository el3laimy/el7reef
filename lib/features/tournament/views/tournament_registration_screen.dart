import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/enums/tournament_registration_status.dart';
import '../../../domain/entities/team.dart';
import '../../../domain/entities/tournament_registration.dart';
import '../controllers/tournament_registration_controller.dart';

class TournamentRegistrationScreen
    extends GetView<TournamentRegistrationController> {
  const TournamentRegistrationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيلات البطولة')),
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          final tournament = controller.tournament.value;
          if (tournament == null) {
            return _CenteredState(
              icon: Icons.error_outline_rounded,
              title: 'تعذر تحميل صفحة التسجيل',
              message: controller.errorMessage.value.isEmpty
                  ? 'لم نتمكن من العثور على البطولة المطلوبة.'
                  : controller.errorMessage.value,
            );
          }

          final pendingRegistrations = controller.pendingRegistrations;
          final approvedRegistrations = controller.approvedRegistrations;
          final rejectedRegistrations = controller.rejectedRegistrations;
          final myTeams = controller.myTeams;
          final canManageRegistrations = controller.isOrganizer;

          return RefreshIndicator(
            onRefresh: controller.loadScreen,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _TournamentSummaryCard(
                  tournamentName: tournament.name,
                  approvedCount: approvedRegistrations.length,
                  pendingCount: pendingRegistrations.length,
                  rejectedCount: rejectedRegistrations.length,
                  maxTeams: tournament.maxTeams,
                ),
                const SizedBox(height: 16),
                if (!controller.isAuthenticated)
                  const _CenteredState(
                    icon: Icons.login_rounded,
                    title: 'سجّل الدخول أولًا',
                    message:
                        'يمكنك مراجعة التسجيلات الحالية الآن، لكن تسجيل الفرق يتطلب الدخول بالحساب المناسب.',
                  )
                else ...[
                  _SectionTitle(
                    title: canManageRegistrations
                        ? 'تسجيل فريق مسجل'
                        : 'سجّل أحد فرقك',
                    actionLabel: canManageRegistrations ? 'ابحث عن فريق' : null,
                    onActionPressed: canManageRegistrations
                        ? controller.searchRegisteredTeams
                        : null,
                  ),
                  if (canManageRegistrations) ...[
                    TextField(
                      controller: controller.searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => controller.searchRegisteredTeams(),
                      decoration: InputDecoration(
                        hintText: 'ابحث باسم الفريق المسجل',
                        suffixIcon: controller.isSearching.value
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : IconButton(
                                onPressed: controller.searchRegisteredTeams,
                                icon: const Icon(Icons.search_rounded),
                              ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (controller.searchResults.isNotEmpty)
                      ...controller.searchResults.map(
                        (team) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _TeamRegistrationCard(
                            team: team,
                            statusLabel: controller.registrationStatusLabel(
                              controller.registrationForTeam(team.id),
                            ),
                            actionLabel: _teamActionLabel(
                              controller.registrationForTeam(team.id),
                            ),
                            isBusy: controller.isBusyFor(team.id),
                            onPressed: () => controller.registerTeam(team),
                          ),
                        ),
                      )
                    else
                      const Text(
                        'ابحث عن فريق باسمه لإضافته مباشرة إلى البطولة.',
                      ),
                    const SizedBox(height: 16),
                  ],
                  if (myTeams.isNotEmpty) ...[
                    ...myTeams.map(
                      (team) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _TeamRegistrationCard(
                          team: team,
                          statusLabel: controller.registrationStatusLabel(
                            controller.registrationForTeam(team.id),
                          ),
                          actionLabel: _teamActionLabel(
                            controller.registrationForTeam(team.id),
                          ),
                          isBusy: controller.isBusyFor(team.id),
                          onPressed: () => controller.registerTeam(team),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else if (!canManageRegistrations) ...[
                    const _CenteredState(
                      icon: Icons.groups_2_outlined,
                      title: 'لا توجد فرق مرتبطة بهذا الحساب',
                      message:
                          'أنشئ فريقًا أو ادخل بحساب القائد حتى تتمكن من التسجيل في البطولة.',
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
                if (canManageRegistrations) ...[
                  _SectionTitle(
                    title: 'فرق ضيوف وتنظيم التسجيلات',
                    actionLabel: 'إنشاء فريق ضيف',
                    onActionPressed: () async {
                      await Get.toNamed(
                        AppRoutes.tournamentGuestTeamCreateForTournament(
                          tournament.id,
                        ),
                      );
                      await controller.loadScreen();
                    },
                  ),
                  if (pendingRegistrations.isEmpty)
                    const _CenteredState(
                      icon: Icons.fact_check_outlined,
                      title: 'لا توجد طلبات معلّقة',
                      message:
                          'أي فريق ضيف أو طلب تسجيل يحتاج مراجعة سيظهر هنا بمجرد إنشائه.',
                    )
                  else
                    ...pendingRegistrations.map(
                      (registration) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _RegistrationReviewCard(
                          title: controller.participantLabel(registration),
                          subtitle: registration.isGuestRegistration
                              ? 'فريق ضيف بانتظار الاعتماد'
                              : 'فريق مسجل بانتظار الاعتماد',
                          status: registration.status,
                          notes: registration.notes,
                          onPressed: () async {
                            await Get.toNamed(
                              AppRoutes.tournamentRegistrationReviewForTournament(
                                tournament.id,
                                registration.id,
                              ),
                            );
                            await controller.loadScreen();
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
                _SectionTitle(title: 'التسجيلات الحالية'),
                if (approvedRegistrations.isEmpty && rejectedRegistrations.isEmpty)
                  const _CenteredState(
                    icon: Icons.app_registration_rounded,
                    title: 'لا توجد تسجيلات بعد',
                    message:
                        'بمجرد اعتماد أول فريق سيظهر هنا سجل البطولة الحالي.',
                  )
                else ...[
                  ...approvedRegistrations.map(
                    (registration) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RegistrationReviewCard(
                        title: controller.participantLabel(registration),
                        subtitle: registration.isGuestRegistration
                            ? 'فريق ضيف معتمد'
                            : 'فريق مسجل معتمد',
                        status: registration.status,
                        notes: registration.notes,
                        onPressed: canManageRegistrations
                            ? () async {
                                await Get.toNamed(
                                  AppRoutes
                                      .tournamentRegistrationReviewForTournament(
                                    tournament.id,
                                    registration.id,
                                  ),
                                );
                                await controller.loadScreen();
                              }
                            : null,
                      ),
                    ),
                  ),
                  ...rejectedRegistrations.map(
                    (registration) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RegistrationReviewCard(
                        title: controller.participantLabel(registration),
                        subtitle: registration.isGuestRegistration
                            ? 'فريق ضيف مرفوض'
                            : 'فريق مسجل مرفوض',
                        status: registration.status,
                        notes: registration.notes,
                        onPressed: canManageRegistrations
                            ? () async {
                                await Get.toNamed(
                                  AppRoutes
                                      .tournamentRegistrationReviewForTournament(
                                    tournament.id,
                                    registration.id,
                                  ),
                                );
                                await controller.loadScreen();
                              }
                            : null,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ),
    );
  }

  String _teamActionLabel(TournamentRegistration? registration) {
    final status = registration?.status;
    switch (status) {
      case TournamentRegistrationStatus.approved:
        return 'مسجل';
      case TournamentRegistrationStatus.rejected:
        return 'إعادة التسجيل';
      case TournamentRegistrationStatus.pending:
        return 'بانتظار الاعتماد';
      case TournamentRegistrationStatus.cancelled:
        return 'إعادة التفعيل';
      case null:
        return 'تسجيل الآن';
    }
  }
}

class _TournamentSummaryCard extends StatelessWidget {
  final String tournamentName;
  final int approvedCount;
  final int pendingCount;
  final int rejectedCount;
  final int maxTeams;

  const _TournamentSummaryCard({
    required this.tournamentName,
    required this.approvedCount,
    required this.pendingCount,
    required this.rejectedCount,
    required this.maxTeams,
  });

  @override
  Widget build(BuildContext context) {
    final progress = maxTeams == 0 ? 0.0 : approvedCount / maxTeams;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tournamentName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('المعتمد: $approvedCount / $maxTeams'),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _CountChip(label: 'معتمد', count: approvedCount, color: Colors.green),
                _CountChip(label: 'معلّق', count: pendingCount, color: Colors.orange),
                _CountChip(label: 'مرفوض', count: rejectedCount, color: Colors.redAccent),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _CountChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Text(
          '$count',
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ),
      label: Text(label),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

  const _SectionTitle({
    required this.title,
    this.actionLabel,
    this.onActionPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (actionLabel != null && onActionPressed != null)
          TextButton(
            onPressed: onActionPressed,
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

class _TeamRegistrationCard extends StatelessWidget {
  final Team team;
  final String statusLabel;
  final String actionLabel;
  final bool isBusy;
  final VoidCallback onPressed;

  const _TeamRegistrationCard({
    required this.team,
    required this.statusLabel,
    required this.actionLabel,
    required this.isBusy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(team.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('الحالة الحالية: $statusLabel'),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isBusy || statusLabel == 'معتمد' ? null : onPressed,
                icon: isBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.app_registration_rounded),
                label: Text(isBusy ? 'جارٍ التنفيذ...' : actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegistrationReviewCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final TournamentRegistrationStatus status;
  final String? notes;
  final VoidCallback? onPressed;

  const _RegistrationReviewCard({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.notes,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      TournamentRegistrationStatus.approved => Colors.green,
      TournamentRegistrationStatus.pending => Colors.orange,
      TournamentRegistrationStatus.rejected => Colors.redAccent,
      TournamentRegistrationStatus.cancelled => Colors.blueGrey,
    };

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(title),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(subtitle),
              if (notes != null && notes!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('ملاحظات: ${notes!.trim()}'),
              ],
            ],
          ),
        ),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(Icons.assignment_turned_in_rounded, color: color),
        ),
        trailing: onPressed == null
            ? null
            : const Icon(Icons.chevron_right_rounded),
        onTap: onPressed,
      ),
    );
  }
}

class _CenteredState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _CenteredState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
