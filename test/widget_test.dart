import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:el7reef/app/routes/app_pages.dart';
import 'package:el7reef/app/routes/app_routes.dart';
import 'package:el7reef/core/navigation/pending_deep_link_service.dart';
import 'package:el7reef/core/enums/fantasy_league_phase.dart';
import 'package:el7reef/features/fantasy/services/fantasy_lifecycle_service.dart';
import 'package:el7reef/features/fantasy/services/fantasy_market_service.dart';
import 'package:el7reef/core/widgets/feature_unavailable_screen.dart';
import 'package:el7reef/domain/entities/fantasy_league_lifecycle.dart';
import 'package:el7reef/data/repositories/fantasy_lifecycle_repository_impl.dart';
import 'package:el7reef/data/repositories/fantasy_repository_impl.dart';
import 'package:el7reef/data/repositories/player_repository_impl.dart';
import 'package:el7reef/data/repositories/tournament_repository_impl.dart';
import 'package:el7reef/features/auth/views/onboarding_screen.dart';
import 'package:el7reef/features/home/views/home_screen.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    Get.put(FantasyLifecycleRepositoryImpl(firestore: firestore));
    Get.put(FantasyRepositoryImpl(db: firestore));
    Get.put(PlayerRepositoryImpl(firestore: firestore));
    Get.put(TournamentRepositoryImpl(db: firestore));
    Get.put(
      FantasyLifecycleService(
        lifecycleRepository: Get.find<FantasyLifecycleRepositoryImpl>(),
        tournamentRepository: Get.find<TournamentRepositoryImpl>(),
      ),
    );
    Get.put(
      FantasyMarketService(
        fantasyRepository: Get.find<FantasyRepositoryImpl>(),
        playerRepository: Get.find<PlayerRepositoryImpl>(),
      ),
    );
  });

  tearDown(Get.reset);

  testWidgets('App routes bootstrap into the fantasy home screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: AppRoutes.fantasyHome,
        getPages: AppPages.routes,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FeatureUnavailableScreen), findsOneWidget);
    expect(find.text('الفانتازي غير متاح حالياً'), findsWidgets);
    expect(find.text('دوريات الفانتازي'), findsNothing);
  });

  testWidgets('App routes bootstrap into the fantasy team screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: AppRoutes.fantasyTeamForLeague('global'),
        getPages: AppPages.routes,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FeatureUnavailableScreen), findsOneWidget);
    expect(find.text('إدارة الفريق غير متاحة'), findsWidgets);
    expect(find.text('يجب تسجيل الدخول لعرض فريق الفانتازي.'), findsNothing);
  });

  testWidgets('App routes bootstrap into the transfer market screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: AppRoutes.fantasyTransfersForLeague('global'),
        getPages: AppPages.routes,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FeatureUnavailableScreen), findsOneWidget);
    expect(find.text('الانتقالات غير متاحة'), findsWidgets);
    expect(find.text('يجب تسجيل الدخول أولاً.'), findsNothing);
  });

  testWidgets('locked draft route remains hidden behind the V1 fantasy gate', (
    WidgetTester tester,
  ) async {
    await Get.find<FantasyLifecycleRepositoryImpl>().saveLeagueLifecycle(
      FantasyLeagueLifecycle(
        leagueId: 'global',
        currentGameweek: 2,
        phase: FantasyLeaguePhase.locked,
        isLocked: true,
        updatedAt: DateTime(2026, 4, 15, 12),
      ),
    );

    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: AppRoutes.fantasyPickTeamForLeague('global'),
        getPages: AppPages.routes,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FeatureUnavailableScreen), findsOneWidget);
    expect(find.text('إنشاء فريق فانتازي غير متاح'), findsWidgets);
    expect(find.text('الجولة مغلقة'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'حفظ التشكيلة'), findsNothing);
  });

  testWidgets('social routes stay gated while social UI is disabled', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: AppRoutes.friends,
        getPages: AppPages.routes,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FeatureUnavailableScreen), findsOneWidget);
    expect(find.text('الأصدقاء غير متاحين'), findsWidgets);
    expect(find.text('الأصدقاء'), findsNothing);
  });

  testWidgets('social search route stays gated while social UI is disabled', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: AppRoutes.searchPlayers,
        getPages: AppPages.routes,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FeatureUnavailableScreen), findsOneWidget);
    expect(find.text('البحث الاجتماعي غير متاح'), findsWidgets);
    expect(find.text('البحث عن أصدقاء'), findsNothing);
  });

  for (final intent in <({String label, String route})>[
    (label: 'أنظم بطولة', route: AppRoutes.createTournament),
    (label: 'أنا كابتن فريق', route: AppRoutes.createTeam),
    (label: 'أنا لاعب', route: AppRoutes.tournamentExplore),
  ]) {
    testWidgets('onboarding intent preserves ${intent.route} after login', (
      WidgetTester tester,
    ) async {
      final pendingDeepLinkService = Get.put(PendingDeepLinkService());

      await tester.pumpWidget(
        GetMaterialApp(
          getPages: AppPages.routes,
          home: const OnboardingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(intent.label));

      expect(pendingDeepLinkService.take(), intent.route);
    });
  }

  test('every onboarding intent has a registered route', () {
    final registeredRoutes = AppPages.routes.map((page) => page.name).toSet();

    expect(registeredRoutes, contains(AppRoutes.createTournament));
    expect(registeredRoutes, contains(AppRoutes.createTeam));
    expect(registeredRoutes, contains(AppRoutes.tournamentExplore));
  });

  test('home destinations keep navigation labels in page order', () {
    expect(
      HomeScreen.debugNavigationLabels(friendlyMatchTopLevelEnabled: false),
      equals(['البطولات', 'المباريات', 'الفرق', 'أنا']),
    );

    expect(
      HomeScreen.debugNavigationLabels(friendlyMatchTopLevelEnabled: true),
      equals(['الرئيسية', 'البطولات', 'المباريات', 'الفرق', 'أنا']),
    );
  });
}
