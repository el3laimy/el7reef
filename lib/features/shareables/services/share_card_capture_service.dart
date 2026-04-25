import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ShareCardCaptureService {
  const ShareCardCaptureService();

  Future<void> captureAndShare({
    required GlobalKey boundaryKey,
    required String fileName,
    String? text,
    double pixelRatio = 3.2,
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
}
