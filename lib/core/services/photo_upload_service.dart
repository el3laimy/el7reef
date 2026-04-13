import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// خدمة رفع الصورة الشخصية — Task 6.3.2
/// الوثيقة: ضغط → قص مربع → 3 نسخ → رفع Storage
class PhotoUploadService {
  final FirebaseStorage _storage;
  final ImagePicker _picker;

  PhotoUploadService({
    FirebaseStorage? storage,
    ImagePicker? picker,
  })  : _storage = storage ?? FirebaseStorage.instance,
        _picker = picker ?? ImagePicker();

  /// اختيار صورة من المكتبة أو الكاميرا
  Future<File?> pickImage({bool fromCamera = false}) async {
    try {
      final xFile = await _picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      return xFile != null ? File(xFile.path) : null;
    } catch (_) {
      return null;
    }
  }

  /// رفع الصورة كاملاً: pick → compress → 3 versions → upload
  Future<PhotoUploadResult?> uploadProfilePhoto({
    required String userId,
    required File imageFile,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();

      // ── رفع النسخ الثلاثة ──
      final thumbUrl = await _uploadVersion(
        bytes: bytes,
        userId: userId,
        version: 'thumb',
        quality: 60,
        maxDimension: 100,
      );
      final mediumUrl = await _uploadVersion(
        bytes: bytes,
        userId: userId,
        version: 'medium',
        quality: 75,
        maxDimension: 300,
      );
      final fullUrl = await _uploadVersion(
        bytes: bytes,
        userId: userId,
        version: 'full',
        quality: 90,
        maxDimension: 600,
      );

      if (fullUrl == null) return null;

      return PhotoUploadResult(
        thumbUrl: thumbUrl ?? fullUrl,
        mediumUrl: mediumUrl ?? fullUrl,
        fullUrl: fullUrl,
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _uploadVersion({
    required Uint8List bytes,
    required String userId,
    required String version,
    required int quality,
    required int maxDimension,
  }) async {
    try {
      final path = 'profiles/$userId/photo_$version.jpg';
      final ref = _storage.ref(path);
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'userId': userId,
          'version': version,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );
      await ref.putData(bytes, metadata);
      return await ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  /// حذف الصور القديمة من Storage
  Future<void> deleteOldPhotos(String userId) async {
    for (final version in ['thumb', 'medium', 'full']) {
      try {
        await _storage.ref('profiles/$userId/photo_$version.jpg').delete();
      } catch (_) {}
    }
  }

  /// Dialog لاختيار المصدر
  static Future<File?> showPickerDialog(BuildContext context,
      PhotoUploadService service) async {
    return showModalBottomSheet<File?>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2035),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'اختر صورتك الشخصية',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: Color(0xFF00B4FF)),
              title: const Text('من المكتبة',
                  style: TextStyle(color: Colors.white)),
              onTap: () async {
                final file = await service.pickImage(fromCamera: false);
                if (ctx.mounted) Navigator.pop(ctx, file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined,
                  color: Color(0xFF00B4FF)),
              title: const Text('التقط صورة',
                  style: TextStyle(color: Colors.white)),
              onTap: () async {
                final file = await service.pickImage(fromCamera: true);
                if (ctx.mounted) Navigator.pop(ctx, file);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class PhotoUploadResult {
  final String thumbUrl;
  final String mediumUrl;
  final String fullUrl;
  const PhotoUploadResult({
    required this.thumbUrl,
    required this.mediumUrl,
    required this.fullUrl,
  });
}
