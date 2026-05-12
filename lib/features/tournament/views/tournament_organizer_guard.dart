import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../data/repositories/tournament_repository_impl.dart';
import '../../../domain/entities/player.dart';
import '../../../core/auth/auth_service.dart';

class TournamentOrganizerGuard extends StatefulWidget {
  static const accessDeniedMessage = 'لا تملك صلاحية إدارة هذه البطولة.';

  final Widget child;

  const TournamentOrganizerGuard({super.key, required this.child});

  @override
  State<TournamentOrganizerGuard> createState() =>
      _TournamentOrganizerGuardState();
}

class _TournamentOrganizerGuardState extends State<TournamentOrganizerGuard> {
  late final AuthService _authService;
  late final TournamentRepositoryImpl _tournamentRepository;
  Worker? _authWorker;
  Future<bool>? _accessFuture;
  String? _accessKey;
  bool _redirectScheduled = false;

  @override
  void initState() {
    super.initState();
    _authService = Get.find<AuthService>();
    _tournamentRepository = Get.isRegistered<TournamentRepositoryImpl>()
        ? Get.find<TournamentRepositoryImpl>()
        : TournamentRepositoryImpl();
    _authWorker = ever<Player?>(_authService.currentPlayer, (_) {
      _resetAccessCheck();
    });
  }

  @override
  void dispose() {
    _authWorker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _ensureAccessFuture();
    return FutureBuilder<bool>(
      future: _accessFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _GuardLoadingScreen();
        }
        if (snapshot.data == true) {
          return widget.child;
        }
        _scheduleSafeRedirect();
        return const _OrganizerAccessDeniedScreen();
      },
    );
  }

  void _ensureAccessFuture() {
    final tournamentId = _currentTournamentId;
    final actorId = _authService.currentUserId;
    final nextKey = '${tournamentId ?? ''}:${actorId ?? ''}';
    if (_accessKey == nextKey && _accessFuture != null) {
      return;
    }

    _accessKey = nextKey;
    _redirectScheduled = false;
    _accessFuture = _canAccessTournament(
      tournamentId: tournamentId,
      actorId: actorId,
    );
  }

  Future<bool> _canAccessTournament({
    required String? tournamentId,
    required String? actorId,
  }) async {
    if (tournamentId == null ||
        tournamentId.trim().isEmpty ||
        actorId == null ||
        actorId.trim().isEmpty) {
      return false;
    }
    final tournament = await _tournamentRepository.getTournament(tournamentId);
    return tournament != null && tournament.organizerId == actorId;
  }

  void _resetAccessCheck() {
    if (!mounted) return;
    setState(() {
      _accessKey = null;
      _accessFuture = null;
      _redirectScheduled = false;
    });
  }

  void _scheduleSafeRedirect() {
    if (_redirectScheduled) return;
    _redirectScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!Get.testMode) {
        Get.snackbar('غير مسموح', TournamentOrganizerGuard.accessDeniedMessage);
      }
      final tournamentId = _currentTournamentId;
      if (tournamentId != null && tournamentId.trim().isNotEmpty) {
        Get.offNamed(AppRoutes.tournamentDetailById(tournamentId));
      } else if (Get.key.currentState?.canPop() ?? false) {
        Get.back();
      } else {
        Get.offNamed(AppRoutes.tournamentList);
      }
    });
  }

  String? get _currentTournamentId =>
      Get.parameters['tournamentId'] ?? Get.parameters['id'];
}

class _GuardLoadingScreen extends StatelessWidget {
  const _GuardLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _OrganizerAccessDeniedScreen extends StatelessWidget {
  const _OrganizerAccessDeniedScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            TournamentOrganizerGuard.accessDeniedMessage,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
