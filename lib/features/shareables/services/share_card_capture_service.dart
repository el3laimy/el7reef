import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

const double matchResultShareExportPixelRatio = 3.0;

class ShareCardCaptureService {
  const ShareCardCaptureService();

  Future<void> captureAndShare({
    required GlobalKey boundaryKey,
    required String fileName,
    String? text,
    double pixelRatio = matchResultShareExportPixelRatio,
  }) async {
    final context = boundaryKey.currentContext;
    if (context == null) {
      throw Exception('تعذر تجهيز بطاقة المشاركة.');
    }

    final renderObject = context.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      throw Exception('تعذر التقاط بطاقة المشاركة.');
    }

    final image = await renderObject.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('تعذر إنشاء صورة المشاركة.');
    }

    final directory = await getTemporaryDirectory();
    final safeFileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final file = File('${directory.path}/$safeFileName.png');
    await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);

    await Share.shareXFiles([XFile(file.path)], text: text);
  }

  /// التقاط أي ودجت ومشاركتها عبر إدارتها في الـ Overlay
  Future<void> captureAndShareWidget({
    required BuildContext context,
    required Widget widget,
    required String fileName,
    String? text,
    Future<void> Function()? onBeforeCapture,
  }) async {
    final boundaryKey = GlobalKey();
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: 0,
        top: 0,
        child: IgnorePointer(
          child: Opacity(
            opacity: 0.01,
            child: RepaintBoundary(
              key: boundaryKey,
              child: widget,
            ),
          ),
        ),
      ),
    );

    // إظهار مؤشر تحميل
    final loadingDialog = showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );

    var inserted = false;
    try {
      if (onBeforeCapture != null) {
        await onBeforeCapture();
      }

      final overlay = Overlay.maybeOf(context, rootOverlay: true);
      if (overlay == null) throw Exception('تعذر تجهيز نافذة المشاركة.');

      overlay.insert(entry);
      inserted = true;
      
      await WidgetsBinding.instance.endOfFrame;
      // تأخير بسيط لضمان اكتمال الريندر في بعض الحالات المعقدة
      await Future.delayed(const Duration(milliseconds: 100));

      await captureAndShare(
        boundaryKey: boundaryKey,
        fileName: fileName,
        text: text,
      );
    } finally {
      if (inserted) entry.remove();
      // إغلاق ديالوج التحميل
      if (Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }
}
