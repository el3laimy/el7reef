import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:el7reef/app/routes/app_pages.dart';
import 'package:el7reef/app/routes/app_routes.dart';
import 'package:el7reef/core/auth/auth_session.dart';
import 'package:el7reef/core/auth/auth_service.dart';
import 'package:el7reef/core/navigation/pending_deep_link_service.dart';
import 'package:el7reef/core/services/cloud_sensitive_ops_service.dart';
import 'package:el7reef/core/services/guest_claim_service.dart';
import 'package:el7reef/data/repositories/guest_player_repository_impl.dart';
import 'package:el7reef/data/repositories/guest_team_repository_impl.dart';
import 'package:el7reef/data/repositories/player_repository_impl.dart';
import 'package:el7reef/data/repositories/team_repository_impl.dart';
import 'package:el7reef/domain/entities/guest_player.dart';
import 'package:el7reef/domain/entities/guest_team.dart';
import 'package:el7reef/domain/entities/player.dart';
import 'package:el7reef/domain/entities/team.dart';
import 'package:el7reef/features/guest_claim/views/guest_player_claim_screen.dart';
import 'package:el7reef/features/guest_claim/views/guest_team_claim_screen.dart';

const _playerClaimCode = 'PLAYER-CLAIM-CODE';
const _teamClaimCode = 'TEAM-CLAIM-CODE';

void main() {
  late FakeFirebaseFirestore firestore;
  late _FakeCloudSensitiveOpsService cloudOps;

  setUp(() async {
    Get.testMode = true;
    firestore = FakeFirebaseFirestore();

    Get.put<TeamRepositoryImpl>(
      TeamRepositoryImpl(firestore: firestore),
      permanent: true,
    );
    Get.put<PlayerRepositoryImpl>(
      PlayerRepositoryImpl(firestore: firestore),
      permanent: true,
    );
    Get.put<GuestPlayerRepositoryImpl>(
      GuestPlayerRepositoryImpl(firestore: firestore),
      permanent: true,
    );
    Get.put<GuestTeamRepositoryImpl>(
      GuestTeamRepositoryImpl(firestore: firestore),
      permanent: true,
    );
    cloudOps = _FakeCloudSensitiveOpsService();
    Get.put<CloudSensitiveOpsService>(cloudOps, permanent: true);
    Get.put<GuestClaimService>(
      GuestClaimService(cloudOps: cloudOps),
      permanent: true,
    );

    final now = DateTime(2026, 4, 16, 10);
    final playerRepository = Get.find<PlayerRepositoryImpl>();
    final teamRepository = Get.find<TeamRepositoryImpl>();
    final guestPlayerRepository = Get.find<GuestPlayerRepositoryImpl>();
    final guestTeamRepository = Get.find<GuestTeamRepositoryImpl>();

    await playerRepository.createPlayer(
      Player(
        id: 'owner-1',
        name: 'Organizer One',
        createdAt: now,
        lastActiveAt: now,
      ),
    );
    await playerRepository.createPlayer(
      Player(
        id: 'owner-2',
        name: 'Captain Two',
        createdAt: now,
        lastActiveAt: now,
      ),
    );
    await playerRepository.createPlayer(
      Player(
        id: 'player-1',
        name: 'Mahmoud Salem',
        createdAt: now,
        lastActiveAt: now,
      ),
    );

    await teamRepository.createTeam(
      Team(
        id: 'team-2',
        name: 'Blue Sharks',
        ownerId: 'owner-2',
        playerIds: const ['owner-2'],
        createdAt: now,
      ),
    );

    await guestPlayerRepository.createGuestPlayer(
      GuestPlayer(
        id: 'guest-1',
        displayName: 'Mahmoud Guest',
        normalizedName: 'mahmoud guest',
        teamId: 'team-2',
        createdBy: 'owner-1',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await guestTeamRepository.createGuestTeam(
      GuestTeam(
        id: 'guest-team-1',
        name: 'Guest Falcons',
        normalizedName: 'guest falcons',
        creatorId: 'owner-1',
        tournamentIds: const ['street-cup'],
        createdAt: now,
        updatedAt: now,
      ),
    );
  });

  tearDown(Get.reset);

  testWidgets('generic claim route redirects to guest player claim screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        initialRoute: AppRoutes.claimEntryWithQuery({
          'code': _playerClaimCode,
          'type': 'guestPlayer',
          'targetId': 'guest-1',
          'requiresApproval': '0',
        }),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GuestPlayerClaimScreen), findsOneWidget);
    expect(find.text('Mahmoud Guest'), findsOneWidget);
    expect(find.text('سجّل الدخول أولاً حتى تستلم مكانك.'), findsOneWidget);
  });

  testWidgets(
    'SEC-107 route target mismatch is surfaced from callable inspection',
    (WidgetTester tester) async {
      Get.put<AuthSession>(
        _FakeAuthSession(
          currentUserId: 'player-1',
          currentPlayer: Player(
            id: 'player-1',
            name: 'Mahmoud Salem',
            createdAt: DateTime(2026, 4, 16, 10),
            lastActiveAt: DateTime(2026, 4, 16, 10),
          ),
        ),
      );

      await tester.pumpWidget(
        _buildApp(
          initialRoute: AppRoutes.guestPlayerClaimById(
            'forged-route-target',
            queryParameters: {'code': _playerClaimCode},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('رابط الاستلام لا يطابق هذا اللاعب الضيف.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('guest player login action preserves the claim route', (
    WidgetTester tester,
  ) async {
    final pendingDeepLinkService = Get.put(PendingDeepLinkService());
    final route = AppRoutes.guestPlayerClaimById(
      'guest-1',
      queryParameters: {'code': _playerClaimCode},
    );

    await tester.pumpWidget(_buildApp(initialRoute: route));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'تسجيل الدخول'));

    expect(pendingDeepLinkService.take(), route);
  });

  testWidgets('guest player claim route resumes after Google sign-in', (
    WidgetTester tester,
  ) async {
    final signedInPlayer = Player(
      id: 'player-1',
      name: 'Mahmoud Salem',
      createdAt: DateTime(2026, 4, 16, 10),
      lastActiveAt: DateTime(2026, 4, 16, 10),
    );
    Get.put<AuthService>(
      _FakeAuthService(googleSignInResult: signedInPlayer),
      permanent: true,
    );

    await tester.pumpWidget(
      _buildApp(
        initialRoute: AppRoutes.claimEntryWithQuery({
          'code': _playerClaimCode,
          'type': 'guestPlayer',
          'targetId': 'guest-1',
          'requiresApproval': '0',
        }),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'تسجيل الدخول'));
    await tester.pumpAndSettle();

    expect(find.text('سجّل دخولك بـ Google'), findsOneWidget);

    await tester.tap(find.text('أوافق على قواعد المجتمع وسياسة الخصوصية'));
    await tester.pump();
    await tester.tap(
      find.widgetWithText(ElevatedButton, 'سجّل دخولك بـ Google'),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GuestPlayerClaimScreen), findsOneWidget);
    expect(find.text('Mahmoud Guest'), findsOneWidget);
    expect(find.text('سيتم ربط هذا المكان بحسابك الحالي.'), findsOneWidget);
  });

  testWidgets(
    'logged-in player can complete guest player claim from the screen',
    (WidgetTester tester) async {
      Get.put<AuthSession>(
        _FakeAuthSession(
          currentUserId: 'player-1',
          currentPlayer: Player(
            id: 'player-1',
            name: 'Mahmoud Salem',
            createdAt: DateTime(2026, 4, 16, 10),
            lastActiveAt: DateTime(2026, 4, 16, 10),
          ),
        ),
      );

      await tester.pumpWidget(
        _buildApp(
          initialRoute: AppRoutes.guestPlayerClaimById(
            'guest-1',
            queryParameters: {'code': _playerClaimCode},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'استلم مكاني'));
      await tester.pumpAndSettle();

      expect(find.text('تم استلام مكانك بنجاح'), findsOneWidget);
      expect(
        find.text(
          'تم ربط بيانات اللاعب الضيف بحسابك الحالي مع الحفاظ على سجلاته السابقة.',
        ),
        findsOneWidget,
      );
      expect(find.text('افتح بروفايلك'), findsOneWidget);
    },
  );

  testWidgets('expired guest player claim links are blocked in the UI', (
    WidgetTester tester,
  ) async {
    cloudOps.expirePlayerClaim();
    Get.put<AuthSession>(
      _FakeAuthSession(
        currentUserId: 'player-1',
        currentPlayer: Player(
          id: 'player-1',
          name: 'Mahmoud Salem',
          createdAt: DateTime(2026, 4, 16, 10),
          lastActiveAt: DateTime(2026, 4, 16, 10),
        ),
      ),
    );

    await tester.pumpWidget(
      _buildApp(
        initialRoute: AppRoutes.guestPlayerClaimById(
          'guest-1',
          queryParameters: {'code': _playerClaimCode},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'استلم مكاني'));
    await tester.pumpAndSettle();

    expect(find.text('تعذر إكمال العملية'), findsOneWidget);
    expect(find.text('انتهت صلاحية رابط الاستلام.'), findsOneWidget);
  });

  testWidgets('player claim conflicts are surfaced in the claim screen', (
    WidgetTester tester,
  ) async {
    cloudOps.returnPlayerNameConflict();
    Get.put<AuthSession>(
      _FakeAuthSession(
        currentUserId: 'player-1',
        currentPlayer: Player(
          id: 'player-1',
          name: 'Mahmoud Salem',
          createdAt: DateTime(2026, 4, 16, 10),
          lastActiveAt: DateTime(2026, 4, 16, 10),
        ),
      ),
    );

    await tester.pumpWidget(
      _buildApp(
        initialRoute: AppRoutes.guestPlayerClaimById(
          'guest-1',
          queryParameters: {'code': _playerClaimCode},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'استلم مكاني'));
    await tester.pumpAndSettle();

    expect(find.text('يوجد تعارض يحتاج مراجعة'), findsOneWidget);
    expect(
      find.text('توجد هوية أخرى بالاسم نفسه وتحتاج إلى مراجعة.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'logged-in captain can submit a guest team claim request from the screen',
    (WidgetTester tester) async {
      Get.put<AuthSession>(
        _FakeAuthSession(
          currentUserId: 'owner-2',
          currentPlayer: Player(
            id: 'owner-2',
            name: 'Captain Two',
            createdAt: DateTime(2026, 4, 16, 10),
            lastActiveAt: DateTime(2026, 4, 16, 10),
          ),
        ),
      );

      await tester.pumpWidget(
        _buildApp(
          initialRoute: AppRoutes.claimEntryWithQuery({
            'code': _teamClaimCode,
            'type': 'guestTeam',
            'targetId': 'guest-team-1',
            'requiresApproval': '1',
          }),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GuestTeamClaimScreen), findsOneWidget);
      expect(find.text('Blue Sharks'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'إرسال طلب الاستلام'));
      await tester.pumpAndSettle();

      expect(find.text('تم إرسال طلب الاستلام'), findsOneWidget);
      expect(
        find.text(
          'تم حفظ طلب الـ claim. سيحتاج الرابط الآن إلى موافقة منشئ الفريق الضيف لإكمال الربط.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('guest team login action preserves the claim route', (
    WidgetTester tester,
  ) async {
    final pendingDeepLinkService = Get.put(PendingDeepLinkService());
    final route = AppRoutes.guestTeamClaimById(
      'guest-team-1',
      queryParameters: {'code': _teamClaimCode, 'requiresApproval': '1'},
    );

    await tester.pumpWidget(_buildApp(initialRoute: route));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'تسجيل الدخول'));

    expect(pendingDeepLinkService.take(), route);
  });

  testWidgets('guest team claim route resumes after Google sign-in', (
    WidgetTester tester,
  ) async {
    final signedInCaptain = Player(
      id: 'owner-2',
      name: 'Captain Two',
      createdAt: DateTime(2026, 4, 16, 10),
      lastActiveAt: DateTime(2026, 4, 16, 10),
    );
    Get.put<AuthService>(
      _FakeAuthService(googleSignInResult: signedInCaptain),
      permanent: true,
    );

    await tester.pumpWidget(
      _buildApp(
        initialRoute: AppRoutes.claimEntryWithQuery({
          'code': _teamClaimCode,
          'type': 'guestTeam',
          'targetId': 'guest-team-1',
          'requiresApproval': '1',
        }),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'تسجيل الدخول'));
    await tester.pumpAndSettle();

    expect(find.text('سجّل دخولك بـ Google'), findsOneWidget);

    await tester.tap(find.text('أوافق على قواعد المجتمع وسياسة الخصوصية'));
    await tester.pump();
    await tester.tap(
      find.widgetWithText(ElevatedButton, 'سجّل دخولك بـ Google'),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GuestTeamClaimScreen), findsOneWidget);
    expect(find.text('Guest Falcons'), findsOneWidget);
    expect(find.text('Blue Sharks'), findsOneWidget);
    expect(
      find.text('اختر فريقك المسجل الذي تريد ربطه بهذا الفريق الضيف.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'guest team creator can complete a pending approval request from the screen',
    (WidgetTester tester) async {
      cloudOps.seedPendingTeamClaim(canApprove: true);
      Get.put<AuthSession>(
        _FakeAuthSession(
          currentUserId: 'owner-1',
          currentPlayer: Player(
            id: 'owner-1',
            name: 'Organizer One',
            createdAt: DateTime(2026, 4, 16, 10),
            lastActiveAt: DateTime(2026, 4, 16, 10),
          ),
        ),
      );

      await tester.pumpWidget(
        _buildApp(
          initialRoute: AppRoutes.guestTeamClaimById(
            'guest-team-1',
            queryParameters: {'code': _teamClaimCode, 'requiresApproval': '1'},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GuestTeamClaimScreen), findsOneWidget);
      expect(find.text('يوجد طلب claim معلق'), findsOneWidget);
      expect(find.textContaining('Blue Sharks'), findsWidgets);

      await tester.tap(
        find.widgetWithText(FilledButton, 'موافقة المنظم وإتمام الربط'),
      );
      await tester.pumpAndSettle();

      expect(find.text('تم ربط الفريق بنجاح'), findsOneWidget);
      expect(
        find.text(
          'تم ربط الفريق الضيف بالفريق المسجل مع الحفاظ على تاريخ البطولات الحالي.',
        ),
        findsOneWidget,
      );
    },
  );
}

class _FakeCloudSensitiveOpsService extends CloudSensitiveOpsService {
  bool _playerExpired = false;
  bool _playerClaimed = false;
  bool _returnPlayerNameConflict = false;
  bool _teamPendingApproval = false;
  bool _teamClaimed = false;
  bool _canApprovePendingTeamClaim = false;

  void expirePlayerClaim() {
    _playerExpired = true;
  }

  void returnPlayerNameConflict() {
    _returnPlayerNameConflict = true;
  }

  void seedPendingTeamClaim({required bool canApprove}) {
    _teamPendingApproval = true;
    _canApprovePendingTeamClaim = canApprove;
  }

  @override
  Future<Map<String, dynamic>> inspectGuestClaim({
    required String claimCode,
  }) async {
    switch (claimCode) {
      case _playerClaimCode:
        return {
          'targetType': 'guestPlayer',
          'targetId': 'guest-1',
          'subjectName': 'Mahmoud Guest',
          'scope': 'team',
          'teamId': 'team-2',
          'requiresApproval': false,
          'pendingApproval': false,
          'canApprovePendingTeamClaim': false,
          'status': _playerExpired
              ? 'expired'
              : _playerClaimed
              ? 'claimed'
              : 'active',
          'expiresAt': _playerExpired
              ? DateTime(2000, 1, 1).millisecondsSinceEpoch
              : DateTime(2100, 1, 1).millisecondsSinceEpoch,
        };
      case _teamClaimCode:
        return {
          'targetType': 'guestTeam',
          'targetId': 'guest-team-1',
          'subjectName': 'Guest Falcons',
          'scope': 'tournament',
          'teamId': _teamPendingApproval || _teamClaimed ? 'team-2' : null,
          'tournamentId': 'street-cup',
          'requiresApproval': true,
          'pendingApproval': _teamPendingApproval,
          'canApprovePendingTeamClaim': _canApprovePendingTeamClaim,
          'status': _teamClaimed ? 'claimed' : 'active',
          'expiresAt': DateTime(2100, 1, 1).millisecondsSinceEpoch,
        };
      default:
        throw StateError('Unexpected claim code in screen test.');
    }
  }

  @override
  Future<Map<String, dynamic>> claimGuestPlayer({
    required String claimCode,
  }) async {
    if (claimCode != _playerClaimCode) {
      throw StateError('Unexpected player claim code in screen test.');
    }
    if (_playerExpired) {
      return const {'outcome': 'expired'};
    }
    if (_returnPlayerNameConflict) {
      return const {
        'outcome': 'conflict',
        'guestPlayerId': 'guest-1',
        'playerId': 'player-1',
        'conflict': {
          'type': 'duplicateName',
          'conflictingEntityId': 'player-name-dup',
        },
      };
    }
    _playerClaimed = true;
    return const {
      'outcome': 'claimed',
      'guestPlayerId': 'guest-1',
      'playerId': 'player-1',
      'relinkedMembershipIds': <String>[],
      'linkedTeamIds': <String>['team-2'],
      'syncedLegacyTeamIds': <String>['team-2'],
    };
  }

  @override
  Future<Map<String, dynamic>> claimGuestTeam({
    required String claimCode,
    required String teamId,
  }) async {
    if (claimCode != _teamClaimCode || teamId != 'team-2') {
      throw StateError('Unexpected team claim input in screen test.');
    }
    if (_teamPendingApproval && _canApprovePendingTeamClaim) {
      _teamPendingApproval = false;
      _teamClaimed = true;
      return const {
        'outcome': 'claimed',
        'guestTeamId': 'guest-team-1',
        'teamId': 'team-2',
        'mergedTournamentIds': <String>['street-cup'],
      };
    }
    _teamPendingApproval = true;
    return const {
      'outcome': 'approvalRequired',
      'guestTeamId': 'guest-team-1',
      'teamId': 'team-2',
      'mergedTournamentIds': <String>[],
      'requestedByPlayerId': 'owner-2',
    };
  }
}

class _FakeAuthSession implements AuthSession {
  @override
  final String? currentUserId;

  @override
  final Player? currentPlayer;

  const _FakeAuthSession({
    required this.currentUserId,
    required this.currentPlayer,
  });
}

class _FakeAuthService extends GetxService implements AuthService {
  final Player? googleSignInResult;
  final Rx<Player?> _currentPlayer = Rx<Player?>(null);
  final RxBool _isLoading = false.obs;
  final Rx<AuthProfileStatus> _profileStatus =
      AuthProfileStatus.unauthenticated.obs;
  final RxString _profileErrorMessage = ''.obs;

  _FakeAuthService({required this.googleSignInResult});

  @override
  Rx<Player?> get currentPlayer => _currentPlayer;

  @override
  String? get currentUserId => _currentPlayer.value?.id;

  @override
  bool get isLoggedIn => _currentPlayer.value != null;

  @override
  RxBool get isLoading => _isLoading;

  @override
  Rx<AuthProfileStatus> get profileStatus => _profileStatus;

  @override
  RxString get profileErrorMessage => _profileErrorMessage;

  @override
  Future<AuthService> init() async => this;

  @override
  Future<void> refreshProfile() async {}

  @override
  Future<Player?> signInWithGoogle() async {
    _currentPlayer.value = googleSignInResult;
    _profileStatus.value = googleSignInResult == null
        ? AuthProfileStatus.repairRequired
        : AuthProfileStatus.ready;
    return googleSignInResult;
  }

  @override
  Future<void> reauthenticateWithGoogle() async {}

  @override
  Future<void> signOut() async {
    _currentPlayer.value = null;
    _profileStatus.value = AuthProfileStatus.unauthenticated;
  }
}

Widget _buildApp({required String initialRoute}) {
  return GetMaterialApp(initialRoute: initialRoute, getPages: AppPages.routes);
}
