import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firebase_paths.dart';

/// خدمة Username — RULE-01: فريد عالمياً + حجز القديم 14 يوماً
class UsernameService {
  final FirebaseFirestore _firestore;

  UsernameService({FirebaseFirestore? db, FirebaseFirestore? firestore})
    : _firestore = firestore ?? db ?? FirebaseFirestore.instance;

  // ── الكلمات المحجوزة من الوثيقة ──
  static const _reservedWords = {
    'admin',
    'support',
    '7reef',
    'el7reef',
    'elharif',
    'الحريف',
    'moderator',
    'official',
    'system',
    'bot',
    'help',
    'info',
    'staff',
    'team',
    'null',
    'undefined',
  };

  // ── RegExp من الوثيقة ──
  // 3-20 حرف: a-z | 0-9 | _ | .
  // لا يبدأ أو ينتهي بـ _ أو .
  // لا .. أو __ أو ._ أو _. متتاليتان
  static final _usernameRegex = RegExp(r'^[a-z0-9]([a-z0-9._]*[a-z0-9])?$');
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
  Future<bool> isAvailable(String username, {String? currentOwnerId}) async {
    final lower = username.toLowerCase().trim();

    // فحص 1: هل هو مستخدم حالياً؟
    final activeSnap = await _firestore
        .collection(FirebasePaths.players)
        .where('usernameLower', isEqualTo: lower)
        .limit(1)
        .get();

    if (activeSnap.docs.isNotEmpty &&
        activeSnap.docs.first.id != currentOwnerId) {
      return false;
    }

    // فحص 2: هل هو محجوز (تم تغييره مؤخراً)؟
    final reservedSnap = await _firestore
        .collection(FirebasePaths.reservedUsernames)
        .doc(lower)
        .get();

    if (!reservedSnap.exists) {
      return true;
    }

    final data = reservedSnap.data() ?? <String, dynamic>{};
    return _canClaimUsername(
      data: data,
      playerId: currentOwnerId,
      now: DateTime.now(),
    );
  }

  /// حفظ Username جديد وحجز القديم
  Future<UsernameSetResult> setUsername({
    required String playerId,
    required String newUsername,
    String? oldUsername,
  }) async {
    final lower = newUsername.toLowerCase().trim();
    final oldLower = oldUsername?.toLowerCase().trim();

    // فحص محلي أولاً
    final localResult = validateLocally(lower);
    if (localResult != UsernameValidationResult.valid) {
      return UsernameSetResult.validationFailed;
    }

    if (oldLower == lower) {
      return UsernameSetResult.success;
    }

    try {
      await _firestore.runTransaction((transaction) async {
        final now = DateTime.now();
        final playerRef = _firestore
            .collection(FirebasePaths.players)
            .doc(playerId);
        final playerSnapshot = await transaction.get(playerRef);
        if (!playerSnapshot.exists) {
          throw StateError('player-not-found');
        }

        final usernameRef = _firestore
            .collection(FirebasePaths.reservedUsernames)
            .doc(lower);
        final usernameSnapshot = await transaction.get(usernameRef);
        if (usernameSnapshot.exists) {
          final isClaimable = _canClaimUsername(
            data: usernameSnapshot.data() ?? <String, dynamic>{},
            playerId: playerId,
            now: now,
          );
          if (!isClaimable) {
            throw const _UsernameTakenException();
          }
        }

        transaction.update(playerRef, {
          'username': lower,
          'usernameLower': lower,
        });

        transaction.set(usernameRef, {
          'username': lower,
          'ownerId': playerId,
          'status': 'active',
          'claimedAt': now.millisecondsSinceEpoch,
          'expiresAt': null,
        });

        if (oldLower != null && oldLower.isNotEmpty) {
          final reservedRef = _firestore
              .collection(FirebasePaths.reservedUsernames)
              .doc(oldLower);
          transaction.set(reservedRef, {
            'username': oldLower,
            'ownerId': playerId,
            'previousOwnerId': playerId,
            'status': 'reserved',
            'reservedAt': now.millisecondsSinceEpoch,
            'expiresAt': now
                .add(const Duration(days: 14))
                .millisecondsSinceEpoch,
          });
        }
      });
      return UsernameSetResult.success;
    } on _UsernameTakenException {
      return UsernameSetResult.taken;
    } catch (_) {
      return UsernameSetResult.error;
    }
  }

  bool _canClaimUsername({
    required Map<String, dynamic> data,
    required String? playerId,
    required DateTime now,
  }) {
    final ownerId =
        data['ownerId'] as String? ?? data['previousOwnerId'] as String?;
    final status = data['status'] as String?;
    final expiresAt = data['expiresAt'] as int?;

    if (playerId != null && ownerId == playerId) {
      return true;
    }

    if (status == 'active') {
      return false;
    }

    if (expiresAt == null) {
      return true;
    }

    return !DateTime.fromMillisecondsSinceEpoch(expiresAt).isAfter(now);
  }
}

class _UsernameTakenException implements Exception {
  const _UsernameTakenException();
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
    invalidChars => 'أحرف غير مسموحة — استخدم: a-z أو 0-9 أو _ أو .',
    consecutiveSpecial => 'لا يمكن استخدام _ أو . متتاليتان',
    reserved => 'هذا الـ Username محجوز ولا يمكن استخدامه',
  };
}

/// نتيجة حفظ الـ Username
enum UsernameSetResult { success, validationFailed, taken, error }
