import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_text_styles.dart';
import '../utils/app_logger.dart';
import '../widgets/el7reef_glass_surface.dart';

/// خدمة رفع الصورة الشخصية — Task 6.3.2
/// الوثيقة: ضغط → قص مربع → 3 نسخ → رفع Storage
class PhotoUploadService {
  final FirebaseStorage _storage;
  final ImagePicker _picker;

  PhotoUploadService({FirebaseStorage? storage, ImagePicker? picker})
    : _storage = storage ?? FirebaseStorage.instance,
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
    } catch (e) {
      AppLogger.error('PhotoUploadService.pickImage', e);
      return null;
    }
  }

  /// رفع الصورة: pick → upload.
  ///
  /// قرار V1: نرفع نسخة واحدة مضبوطة بالحجم والجودة من `ImagePicker` ونستخدم
  /// نفس الرابط لكل المقاسات. إنشاء نسخ متعددة يحتاج dependency مخصص للضغط
  /// ويُترك لدفعة أداء منفصلة حتى لا نضيف اعتماد جديد داخل إصلاح صغير.
  Future<PhotoUploadResult?> uploadProfilePhoto({
    required String userId,
    required File imageFile,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();

      final fullUrl = await _uploadVersion(
        bytes: bytes,
        userId: userId,
        version: 'full',
      );

      if (fullUrl == null) return null;

      return PhotoUploadResult(
        thumbUrl: fullUrl, // مؤقتاً نفس الصورة
        mediumUrl: fullUrl, // مؤقتاً نفس الصورة
        fullUrl: fullUrl,
      );
    } catch (e) {
      AppLogger.error('PhotoUploadService.uploadProfilePhoto', e);
      return null;
    }
  }

  Future<String?> _uploadVersion({
    required Uint8List bytes,
    required String userId,
    required String version,
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
    } catch (e) {
      AppLogger.error('PhotoUploadService._uploadVersion', e);
      return null;
    }
  }

  /// حذف الصور القديمة من Storage
  Future<void> deleteOldPhotos(String userId) async {
    for (final version in ['thumb', 'medium', 'full']) {
      try {
        await _storage.ref('profiles/$userId/photo_$version.jpg').delete();
      } catch (e) {
        AppLogger.error('PhotoUploadService.deleteOldPhotos.$version', e);
      }
    }
  }

  /// Dialog لاختيار المصدر
  static Future<File?> showPickerDialog(
    BuildContext context,
    PhotoUploadService service,
  ) async {
    return showModalBottomSheet<File?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => El7reefGlassSurface(
        variant: El7reefGlassVariant.sheet,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusXl),
        ),
        padding: EdgeInsets.only(
          left: AppDimensions.lg,
          right: AppDimensions.lg,
          top: AppDimensions.md,
          bottom: MediaQuery.of(ctx).padding.bottom + AppDimensions.lg,
        ),
        child: SafeArea(
          top: false,
          bottom: false,
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
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.md,
                ),
                child: Text(
                  'اختر صورتك الشخصية',
                  style: AppTextStyles.titleLarge,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: AppColors.primary,
                ),
                title: Text('من المكتبة', style: AppTextStyles.titleMedium),
                onTap: () async {
                  final file = await service.pickImage(fromCamera: false);
                  if (ctx.mounted) Navigator.pop(ctx, file);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_outlined,
                  color: AppColors.primary,
                ),
                title: Text('التقط صورة', style: AppTextStyles.titleMedium),
                subtitle: const Text(
                  'سيُطلب إذن الكاميرا فقط عند اختيار هذا الإجراء.',
                ),
                onTap: () async {
                  final file = await service.pickImage(fromCamera: true);
                  if (ctx.mounted) Navigator.pop(ctx, file);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
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
