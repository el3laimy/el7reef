import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firebase_paths.dart';

/// خدمة Username — RULE-01: فريد عالمياً + حجز القديم 14 يوماً
class UsernameService {
  final FirebaseFirestore _db;

  UsernameService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  // ── الكلمات المحجوزة من الوثيقة ──
  static const _reservedWords = {
    'admin', 'support', '7reef', 'el7reef', 'elharif', 'الحريف',
    'moderator', 'official', 'system', 'bot', 'help', 'info',
    'staff', 'team', 'null', 'undefined',
  };

  // ── RegExp من الوثيقة ──
  // 3-20 حرف: a-z | 0-9 | _ | .
  // لا يبدأ أو ينتهي بـ _ أو .
  // لا .. أو __ أو ._ أو _. متتاليتان
  static final _usernameRegex =
      RegExp(r'^[a-z0-9]([a-z0-9._]*[a-z0-9])?$');
  static final _consecutiveSpecialRegex = RegExp(r'[._]{2}');

  /// التحقق من صحة الـ Username محلياً
  UsernameValidationResult validateLocally(String username) {
    final lower = username.toLowerCase().trim();

    if (lower.length < 3) {
      return UsernameValidationResult.tooShort;
    }
    if (lower.length > 20) {
      return UsernameValidationResult.tooLong;
    }
    if (!_usernameRegex.hasMatch(lower)) {
      return UsernameValidationResult.invalidChars;
    }
    if (_consecutiveSpecialRegex.hasMatch(lower)) {
      return UsernameValidationResult.consecutiveSpecial;
    }
    if (_reservedWords.contains(lower)) {
      return UsernameValidationResult.reserved;
    }
    return UsernameValidationResult.valid;
  }

  /// فحص التوفر على Firestore (case-insensitive)
  Future<bool> isAvailable(String username) async {
    final lower = username.toLowerCase().trim();

    // فحص 1: هل هو مستخدم حالياً؟
    final activeSnap = await _db
        .collection(FirebasePaths.players)
        .where('usernameLower', isEqualTo: lower)
        .limit(1)
        .get();

    if (activeSnap.docs.isNotEmpty) return false;

    // فحص 2: هل هو محجوز (تم تغييره مؤخراً)؟
    final reservedSnap = await _db
        .collection(FirebasePaths.reservedUsernames)
        .doc(lower)
        .get();

    if (reservedSnap.exists) {
      final expiresAt = reservedSnap.data()?['expiresAt'] as int?;
      if (expiresAt != null &&
          DateTime.fromMillisecondsSinceEpoch(expiresAt)
              .isAfter(DateTime.now())) {
        return false; // لا يزال في فترة الحجز 14 يوماً
      }
    }

    return true;
  }

  /// حفظ Username جديد وحجز القديم
  Future<UsernameSetResult> setUsername({
    required String playerId,
    required String newUsername,
    String? oldUsername,
  }) async {
    final lower = newUsername.toLowerCase().trim();

    // فحص محلي أولاً
    final localResult = validateLocally(lower);
    if (localResult != UsernameValidationResult.valid) {
      return UsernameSetResult.validationFailed;
    }

    // فحص Firestore
    final available = await isAvailable(lower);
    if (!available) return UsernameSetResult.taken;

    final batch = _db.batch();

    // تحديث بروفايل اللاعب
    final playerRef =
        _db.collection(FirebasePaths.players).doc(playerId);
    batch.update(playerRef, {
      'username': lower,
      'usernameLower': lower,
    });

    // حجز الـ Username القديم لمدة 14 يوماً
    if (oldUsername != null && oldUsername.isNotEmpty) {
      final oldLower = oldUsername.toLowerCase();
      final reservedRef = _db
          .collection(FirebasePaths.reservedUsernames)
          .doc(oldLower);
      batch.set(reservedRef, {
        'username': oldLower,
        'previousOwnerId': playerId,
        'reservedAt': DateTime.now().millisecondsSinceEpoch,
        'expiresAt': DateTime.now()
            .add(const Duration(days: 14))
            .millisecondsSinceEpoch,
      });
    }

    await batch.commit();
    return UsernameSetResult.success;
  }
}

/// نتيجة التحقق المحلي
enum UsernameValidationResult {
  valid,
  tooShort,
  tooLong,
  invalidChars,
  consecutiveSpecial,
  reserved;

  String get message => switch (this) {
    valid => '',
    tooShort => 'الـ Username قصير جداً — ٣ أحرف على الأقل',
    tooLong => 'الـ Username طويل جداً — ٢٠ حرف كحد أقصى',
    invalidChars =>
      'أحرف غير مسموحة — استخدم: a-z أو 0-9 أو _ أو .',
    consecutiveSpecial =>
      'لا يمكن استخدام _ أو . متتاليتان',
    reserved => 'هذا الـ Username محجوز ولا يمكن استخدامه',
  };
}

/// نتيجة حفظ الـ Username
enum UsernameSetResult {
  success,
  validationFailed,
  taken,
  error;
}
