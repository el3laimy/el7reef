import '../../../data/repositories/guest_team_repository_impl.dart';
import '../../../data/repositories/team_repository_impl.dart';
import '../models/public_team_profile_data.dart';

class PublicTeamProfileResolver {
  final TeamRepositoryImpl _teamRepository;
  final GuestTeamRepositoryImpl _guestTeamRepository;

  PublicTeamProfileResolver({
    TeamRepositoryImpl? teamRepository,
    GuestTeamRepositoryImpl? guestTeamRepository,
  }) : _teamRepository = teamRepository ?? TeamRepositoryImpl(),
       _guestTeamRepository = guestTeamRepository ?? GuestTeamRepositoryImpl();

  Future<PublicTeamProfileData?> resolve({
    required String kind,
    required String id,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) return null;

    switch (kind.trim()) {
      case 'registeredTeam':
        final team = await _teamRepository.getTeam(normalizedId);
        if (team == null) return null;
        return PublicTeamProfileData(
          kind: 'registeredTeam',
          id: team.id,
          name: team.name,
          logoUrl: _normalizedOptional(team.logoUrl),
          playerCount: team.playerCount,
          wins: team.wins,
          totalMatches: team.totalMatches,
        );
      case 'guestTeam':
        final team = await _guestTeamRepository.getGuestTeam(normalizedId);
        if (team == null) return null;
        return PublicTeamProfileData(
          kind: 'guestTeam',
          id: team.id,
          name: team.name,
          logoUrl: _normalizedOptional(team.logoUrl),
        );
      default:
        return null;
    }
  }

  String? _normalizedOptional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
