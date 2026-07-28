import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/enums/tournament_registration_mode.dart';
import '../../../core/identity/identity_preset.dart';
import '../../../core/identity/identity_preset_field.dart';
import '../controllers/tournament_guest_team_create_controller.dart';

class TournamentGuestTeamCreateScreen
    extends GetView<TournamentGuestTeamCreateController> {
  const TournamentGuestTeamCreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إنشاء فريق ضيف')),
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          final tournament = controller.tournament.value;
          if (tournament == null) {
            return _InfoState(
              icon: Icons.error_outline_rounded,
              title: 'تعذر تحميل البطولة',
              message: controller.errorMessage.value.isEmpty
                  ? 'لم نتمكن من العثور على البطولة المطلوبة.'
                  : controller.errorMessage.value,
            );
          }

          if (!controller.isOrganizer) {
            return const _InfoState(
              icon: Icons.lock_outline_rounded,
              title: 'صلاحية غير كافية',
              message:
                  'هذه الشاشة متاحة لمنظّم البطولة فقط حتى يتمكن من إنشاء الفرق الضيفة واعتمادها.',
            );
          }

          return Form(
            key: controller.formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tournament.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'أنشئ فريقًا ضيفًا ثم حدّد هل تريد اعتماده مباشرة أم تركه بانتظار مراجعة لاحقة.',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller.teamNameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم الفريق',
                    border: OutlineInputBorder(),
                  ),
                  validator: controller.validateTeamName,
                ),
                const SizedBox(height: 12),
                IdentityPresetField(
                  scope: IdentityPresetScope.team,
                  value: controller.selectedLogoUrl.value,
                  previewTitleController: controller.teamNameController,
                  onChanged: controller.selectLogo,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: controller.contactNameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم مسؤول التواصل',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: controller.contactPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'رقم التواصل',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<TournamentRegistrationMode>(
                  initialValue: controller.selectedMode.value,
                  decoration: const InputDecoration(
                    labelText: 'طريقة التسجيل',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: TournamentRegistrationMode.quick,
                      child: Text('اعتماد مباشر'),
                    ),
                    DropdownMenuItem(
                      value: TournamentRegistrationMode.hybrid,
                      child: Text('إنشاء طلب بانتظار الاعتماد'),
                    ),
                    DropdownMenuItem(
                      value: TournamentRegistrationMode.verified,
                      child: Text('اعتماد موثّق'),
                    ),
                  ],
                  onChanged: controller.selectMode,
                ),
                if (controller.errorMessage.value.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    controller.errorMessage.value,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: controller.isSubmitting.value
                      ? null
                      : controller.submit,
                  icon: controller.isSubmitting.value
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_circle_outline_rounded),
                  label: Text(
                    controller.isSubmitting.value
                        ? 'جارٍ إنشاء الفريق...'
                        : 'إنشاء الفريق الضيف',
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _InfoState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _InfoState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
