import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:el7reef/app/routes/app_pages.dart';
import 'package:el7reef/app/routes/app_routes.dart';
import 'package:el7reef/core/services/fantasy_lifecycle_service.dart';
import 'package:el7reef/core/services/fantasy_market_service.dart';
import 'package:el7reef/data/repositories/fantasy_lifecycle_repository_impl.dart';
import 'package:el7reef/data/repositories/fantasy_repository_impl.dart';
import 'package:el7reef/data/repositories/player_repository_impl.dart';
import 'package:el7reef/data/repositories/tournament_repository_impl.dart';
import 'package:el7reef/features/fantasy/presentation/screens/fantasy_league_list_screen.dart';
import 'package:el7reef/features/fantasy/presentation/screens/fantasy_team_screen.dart';
import 'package:el7reef/features/fantasy/presentation/screens/transfer_market_screen.dart';

void main() {
  setUp(() {
    final firestore = FakeFirebaseFirestore();
    Get.put(FantasyLifecycleRepositoryImpl(db: firestore));
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

  testWidgets('App routes bootstrap into the fantasy home screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: AppRoutes.fantasyHome,
        getPages: AppPages.routes,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FantasyLeagueListScreen), findsOneWidget);
    expect(find.text('دوريات الفانتازي'), findsOneWidget);
    expect(find.text('الدوري العالمي'), findsOneWidget);
  });

  testWidgets('App routes bootstrap into the fantasy team screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: AppRoutes.fantasyTeamForLeague('global'),
        getPages: AppPages.routes,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FantasyTeamScreen), findsOneWidget);
    expect(find.text('يجب تسجيل الدخول لعرض فريق الفانتازي.'), findsOneWidget);
  });

  testWidgets('App routes bootstrap into the transfer market screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: AppRoutes.fantasyTransfersForLeague('global'),
        getPages: AppPages.routes,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TransferMarketScreen), findsOneWidget);
    expect(find.text('يجب تسجيل الدخول أولاً.'), findsOneWidget);
  });
}
