import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:get/get.dart';
import 'session_reset_coordinator.dart';
import '../../../app/routes/app_routes.dart';
import '../constants/app_constants.dart';
import '../../data/repositories/player_repository_impl.dart';
import '../../domain/entities/player.dart';

/// خدمة المصادقة — Google Sign-In + إنشاء حساب تلقائي
class AuthService extends GetxService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final PlayerRepositoryImpl _playerRepo = PlayerRepositoryImpl();
  late final SessionResetCoordinator _sessionResetCoordinator;

  /// اللاعب الحالي
  final Rx<Player?> currentPlayer = Rx<Player?>(null);

  /// حالة التحميل
  final RxBool isLoading = false.obs;

  /// هل المستخدم مسجل؟
  bool get isLoggedIn => _auth.currentUser != null;

  /// معرف المستخدم الحالي
  String? get currentUserId => _auth.currentUser?.uid;

  /// تهيئة الخدمة
  Future<AuthService> init() async {
    _sessionResetCoordinator = Get.isRegistered<SessionResetCoordinator>()
        ? Get.find<SessionResetCoordinator>()
        : Get.put(SessionResetCoordinator(), permanent: true);
    _auth.authStateChanges().listen(_onAuthStateChanged);
    return this;
  }

  /// عند تغيير حالة المصادقة
  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser != null) {
      if (currentPlayer.value != null &&
          currentPlayer.value!.id != firebaseUser.uid) {
        currentPlayer.value = null;
      }
      await _sessionResetCoordinator.handleAuthUidChanged(firebaseUser.uid);
      await _loadPlayerProfile(firebaseUser.uid);
    } else {
      currentPlayer.value = null;
      await _sessionResetCoordinator.handleAuthUidChanged(null);
    }
  }

  /// تحميل بروفايل اللاعب
  Future<void> _loadPlayerProfile(String uid) async {
    try {
      Player? player = await _playerRepo.getPlayer(uid);
      
      // Auto-recovery: If Auth exists but Firestore profile is missing
      if (player == null && _auth.currentUser != null) {
        final firebaseUser = _auth.currentUser!;
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
        await _playerRepo.createPlayer(player);
      }

      currentPlayer.value = player;
      if (player != null) {
        await _sessionResetCoordinator.handleSessionStarted(uid);
      } else {
        await signOut(); // Fallback if recovery fails
        Get.offAllNamed(AppRoutes.login);
      }
    } catch (e, stack) {
      print('🔥 AuthService Error in _loadPlayerProfile: $e');
      print(stack);
      currentPlayer.value = null;
      await signOut(); // Force logout to escape broken session state
      Get.offAllNamed(AppRoutes.login);
    }
  }

  /// ── تسجيل دخول بـ Google ──
  Future<Player?> signInWithGoogle() async {
    try {
      isLoading.value = true;

      // بدء عملية Google Sign-In
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // المستخدم ألغى العملية
        return null;
      }

      // الحصول على بيانات المصادقة
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // إنشاء credential لـ Firebase
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // تسجيل الدخول في Firebase
      final userCredential = await _auth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;

      if (firebaseUser == null) return null;

      if (currentPlayer.value != null &&
          currentPlayer.value!.id != firebaseUser.uid) {
        currentPlayer.value = null;
      }
      await _sessionResetCoordinator.handleAuthUidChanged(firebaseUser.uid);

      // التحقق: هل اللاعب موجود في Firestore؟
      Player? player = await _playerRepo.getPlayer(firebaseUser.uid);

      if (player == null) {
        // لاعب جديد — إنشاء بروفايل تلقائي (AUTO-03)
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
        await _playerRepo.createPlayer(player);
      }

      currentPlayer.value = player;
      await _sessionResetCoordinator.handleSessionStarted(firebaseUser.uid);
      return player;
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    } catch (e) {
      throw 'حدث خطأ أثناء تسجيل الدخول: $e';
    } finally {
      isLoading.value = false;
    }
  }

  /// تسجيل الخروج
  Future<void> signOut() async {
    currentPlayer.value = null;
    await _sessionResetCoordinator.resetForSignOut();
    await _googleSignIn.signOut();
    await _auth.signOut();
    currentPlayer.value = null;
  }

  /// إعادة تحميل البروفايل
  Future<void> refreshProfile() async {
    if (currentUserId != null) {
      await _loadPlayerProfile(currentUserId!);
    }
  }

  /// ترجمة أخطاء Firebase للعربي
  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'account-exists-with-different-credential':
        return 'الحساب مسجل بطريقة تانية';
      case 'invalid-credential':
        return 'بيانات الدخول غير صحيحة';
      case 'operation-not-allowed':
        return 'طريقة الدخول غير مفعّلة';
      case 'user-disabled':
        return 'الحساب معطّل';
      case 'too-many-requests':
        return 'محاولات كثيرة جداً، حاول لاحقاً';
      case 'network-request-failed':
        return 'لا يوجد اتصال بالإنترنت';
      default:
        return 'حدث خطأ غير متوقع: ${e.message}';
    }
  }
}
