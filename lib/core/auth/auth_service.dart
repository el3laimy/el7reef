import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'auth_error_mapper.dart';
import 'auth_firebase_gateway.dart';
import 'session_reset_coordinator.dart';
import '../constants/app_constants.dart';
import '../navigation/pending_deep_link_service.dart';
import '../utils/app_logger.dart';
import '../../data/repositories/player_repository_impl.dart';
import '../../domain/entities/player.dart';
import '../../domain/repositories/player_repository.dart';

enum AuthProfileStatus {
  unknown,
  unauthenticated,
  loading,
  ready,
  repairRequired,
}

/// خدمة المصادقة — Google Sign-In + إنشاء حساب تلقائي
class AuthService extends GetxService {
  static const _profileLoadTimeout = Duration(seconds: 10);

  final AuthFirebaseGateway _authGateway;
  final AuthGoogleGateway _googleGateway;
  final PlayerRepository _playerRepo;
  final SessionResetCoordinator? _providedSessionResetCoordinator;
  late final SessionResetCoordinator _sessionResetCoordinator;

  AuthService({
    AuthFirebaseGateway? authGateway,
    AuthGoogleGateway? googleGateway,
    PlayerRepository? playerRepository,
    SessionResetCoordinator? sessionResetCoordinator,
  }) : _authGateway = authGateway ?? FirebaseAuthGateway(),
       _googleGateway = googleGateway ?? GoogleSignInGateway(),
       _playerRepo = playerRepository ?? PlayerRepositoryImpl(),
       _providedSessionResetCoordinator = sessionResetCoordinator;

  /// اللاعب الحالي
  final Rx<Player?> currentPlayer = Rx<Player?>(null);

  /// حالة التحميل
  final RxBool isLoading = false.obs;

  /// حالة تجهيز بروفايل اللاعب بعد نجاح Firebase Auth
  final Rx<AuthProfileStatus> profileStatus = AuthProfileStatus.unknown.obs;

  /// رسالة قابلة للعرض عند فشل تجهيز البروفايل
  final RxString profileErrorMessage = ''.obs;

  Future<Player?>? _profileLoadInFlight;
  String? _profileLoadUid;

  /// هل المستخدم مسجل؟
  bool get isLoggedIn => _authGateway.currentUser != null;

  /// معرف المستخدم الحالي
  String? get currentUserId => _authGateway.currentUser?.uid;

  /// تهيئة الخدمة
  Future<AuthService> init() async {
    _sessionResetCoordinator =
        _providedSessionResetCoordinator ??
        (Get.isRegistered<SessionResetCoordinator>()
            ? Get.find<SessionResetCoordinator>()
            : Get.put(SessionResetCoordinator(), permanent: true));
    _authGateway.authStateChanges().listen(_onAuthStateChanged);
    final firebaseUser = _authGateway.currentUser;
    if (firebaseUser == null) {
      profileStatus.value = AuthProfileStatus.unauthenticated;
    } else {
      await _loadPlayerProfile(firebaseUser.uid);
    }
    return this;
  }

  /// عند تغيير حالة المصادقة
  Future<void> _onAuthStateChanged(AuthFirebaseUser? firebaseUser) async {
    if (firebaseUser != null) {
      if (currentPlayer.value != null &&
          currentPlayer.value!.id != firebaseUser.uid) {
        currentPlayer.value = null;
      }
      await _sessionResetCoordinator.handleAuthUidChanged(firebaseUser.uid);
      await _loadPlayerProfile(firebaseUser.uid);
    } else {
      currentPlayer.value = null;
      profileErrorMessage.value = '';
      profileStatus.value = AuthProfileStatus.unauthenticated;
      await _sessionResetCoordinator.handleAuthUidChanged(null);
    }
  }

  /// تحميل بروفايل اللاعب
  Future<Player?> _loadPlayerProfile(String uid) {
    final inFlight = _profileLoadInFlight;
    if (_profileLoadUid == uid && inFlight != null) {
      return inFlight;
    }

    _profileLoadUid = uid;
    _profileLoadInFlight = _loadPlayerProfileUnchecked(uid).whenComplete(() {
      _profileLoadInFlight = null;
      _profileLoadUid = null;
    });
    return _profileLoadInFlight!;
  }

  Future<Player?> _loadPlayerProfileUnchecked(String uid) async {
    try {
      profileStatus.value = AuthProfileStatus.loading;
      profileErrorMessage.value = '';
      Player? player = await _playerRepo
          .getPlayer(uid)
          .timeout(_profileLoadTimeout);

      // Auto-recovery: If Auth exists but Firestore profile is missing
      if (player == null && _authGateway.currentUser != null) {
        final firebaseUser = _authGateway.currentUser!;
        final now = DateTime.now();
        player = Player(
          id: firebaseUser.uid,
          name: firebaseUser.displayName ?? 'حريف جديد',
          photoUrl: firebaseUser.photoURL,
          qrCode: '7reef://player/${firebaseUser.uid}',
          photoFrame: 'newcomer',
          phone: firebaseUser.phoneNumber,
          rating: AppConstants.baseRating,
          createdAt: now,
          lastActiveAt: now,
        );
        await _playerRepo.createPlayer(player).timeout(_profileLoadTimeout);
      }

      currentPlayer.value = player;
      if (player != null) {
        profileStatus.value = AuthProfileStatus.ready;
        await _sessionResetCoordinator.handleSessionStarted(uid);
        return player;
      }

      profileStatus.value = AuthProfileStatus.repairRequired;
      profileErrorMessage.value = 'تعذر تجهيز حسابك حالياً. حاول مرة أخرى.';
      return null;
    } catch (e, stack) {
      AppLogger.error('AuthService._loadPlayerProfile', e, stack);
      currentPlayer.value = null;
      profileStatus.value = AuthProfileStatus.repairRequired;
      profileErrorMessage.value = AuthErrorMapper.mapProfileLoadError(e);
      return null;
    }
  }

  /// ── تسجيل دخول بـ Google ──
  Future<Player?> signInWithGoogle() async {
    try {
      isLoading.value = true;

      // بدء عملية Google Sign-In
      final googleUser = await _googleGateway.signIn();
      if (googleUser == null) {
        // المستخدم ألغى العملية
        return null;
      }

      // الحصول على بيانات المصادقة
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      if (googleAuth.idToken == null && googleAuth.accessToken == null) {
        throw PlatformException(
          code: 'missing_google_auth_token',
          message: 'Google Sign-In returned no auth token.',
        );
      }

      // إنشاء credential لـ Firebase
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // تسجيل الدخول في Firebase
      final firebaseUser = await _authGateway.signInWithCredential(credential);

      if (firebaseUser == null) return null;

      if (currentPlayer.value != null &&
          currentPlayer.value!.id != firebaseUser.uid) {
        currentPlayer.value = null;
      }
      await _sessionResetCoordinator.handleAuthUidChanged(firebaseUser.uid);

      return _loadPlayerProfile(firebaseUser.uid);
    } on FirebaseAuthException catch (e) {
      throw AuthErrorMapper.mapAuthError(e);
    } on PlatformException catch (e) {
      throw AuthErrorMapper.mapPlatformSignInError(e);
    } catch (e) {
      throw AuthErrorMapper.mapUnexpectedSignInError(e);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> reauthenticateWithGoogle() async {
    final googleUser = await _googleGateway.signIn();
    if (googleUser == null) {
      throw const AuthDisplayException('يجب تأكيد حساب Google قبل حذف الحساب.');
    }
    final googleAuth = await googleUser.authentication;
    if (googleAuth.idToken == null && googleAuth.accessToken == null) {
      throw const AuthDisplayException(
        'تعذر تأكيد حساب Google. حاول مرة أخرى.',
      );
    }
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    try {
      await _authGateway.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (error) {
      throw AuthErrorMapper.mapAuthError(error);
    }
  }

  /// تسجيل الخروج
  Future<void> signOut() async {
    if (Get.isRegistered<PendingDeepLinkService>()) {
      Get.find<PendingDeepLinkService>().clear();
    }
    currentPlayer.value = null;
    profileErrorMessage.value = '';
    profileStatus.value = AuthProfileStatus.unauthenticated;
    await _sessionResetCoordinator.resetForSignOut();
    await _googleGateway.signOut();
    await _authGateway.signOut();
    currentPlayer.value = null;
  }

  /// إعادة تحميل البروفايل
  Future<void> refreshProfile() async {
    if (currentUserId != null) {
      await _loadPlayerProfile(currentUserId!);
    } else {
      profileStatus.value = AuthProfileStatus.unauthenticated;
    }
  }
}
