import 'package:el7reef/domain/entities/team.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('copyWith preserves an omitted logo and clears an explicit null', () {
    final team = Team(
      id: 'team-1',
      name: 'نسور الحارة',
      logoUrl: 'preset://v1/team_badge/falcon_wing',
      ownerId: 'owner-1',
      createdAt: DateTime.utc(2026, 7, 24),
    );

    expect(team.copyWith().logoUrl, team.logoUrl);
    expect(team.copyWith(logoUrl: null).logoUrl, isNull);
  });
}
