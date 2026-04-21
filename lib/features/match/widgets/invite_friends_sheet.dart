import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../social/controllers/friend_controller.dart';
import '../controllers/match_lobby_controller.dart';
import '../../../domain/entities/match_invitation.dart';

class InviteFriendsSheet extends StatelessWidget {
  final MatchLobbyController lobbyController;
  final String side;

  const InviteFriendsSheet({
    super.key,
    required this.lobbyController,
    required this.side,
  });

  @override
  Widget build(BuildContext context) {
    final friendController = Get.find<FriendController>();

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusXl),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ادعُ أصدقاءك لفريق $side',
                style: AppTextStyles.headlineMedium,
              ),
              TextButton.icon(
                onPressed: () => _showAddGuestDialog(context),
                icon: const Icon(Icons.person_add_alt),
                label: const Text('إضافة ضيف'),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          Expanded(
            child: Obx(() {
              if (friendController.isLoading.value && friendController.friends.isEmpty) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }

              if (friendController.friends.isEmpty) {
                return Center(
                  child: Text(
                    'لا يوجد لديك أصدقاء بعد',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
                  ),
                );
              }

              return ListView.builder(
                itemCount: friendController.friends.length,
                itemBuilder: (context, index) {
                  final friendship = friendController.friends[index];
                  final friendId = friendship.getOtherUserId(friendController.currentUserId!);
                  final friendProfile = friendController.friendProfiles[friendId];

                  if (friendProfile == null) return const SizedBox.shrink();

                  // Check if already in the match
                  final isAlreadyInMatch = lobbyController.teamAPlayers.any((p) => p.id == friendId) ||
                                           lobbyController.teamBPlayers.any((p) => p.id == friendId);

                  // Check if already invited
                  final isInvited = lobbyController.sentInvitations.any(
                    (inv) => inv.receiverId == friendId && inv.status == InvitationStatus.pending
                  );

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primarySurface,
                      backgroundImage: friendProfile.photoThumbUrl != null
                          ? NetworkImage(friendProfile.photoThumbUrl!)
                          : null,
                      child: friendProfile.photoThumbUrl == null
                          ? const Icon(Icons.person, color: AppColors.primary)
                          : null,
                    ),
                    title: Text(friendProfile.name, style: AppTextStyles.titleMedium),
                    subtitle: Text('@${friendProfile.username ?? 'user'}', style: AppTextStyles.labelSmall),
                    trailing: isAlreadyInMatch
                        ? Text('موجود', style: AppTextStyles.labelMedium.copyWith(color: AppColors.success))
                        : isInvited
                            ? Text('مدعو', style: AppTextStyles.labelMedium.copyWith(color: AppColors.textMuted))
                            : TextButton(
                                onPressed: () {
                                  lobbyController.inviteFriend(friendId, side);
                                },
                                child: const Text('دعوة'),
                              ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  void _showAddGuestDialog(BuildContext context) {
    final nameController = TextEditingController();

    Get.dialog(
      AlertDialog(
        title: const Text('إضافة لاعب ضيف'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'اسم اللاعب',
            hintText: 'أدخل اسم اللاعب الضيف',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Get.back(); // close dialog
                lobbyController.addGuestPlayer(nameController.text.trim(), side);
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }
}
