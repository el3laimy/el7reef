import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../core/constants/feature_flags.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../domain/entities/share_payload.dart';
import '../models/pride_export.dart';
import 'pride_share_text_builder.dart';
import 'pride_video_export_service.dart';

const double matchResultShareExportPixelRatio = 3.0;
const Duration sharePreparationTimeout = Duration(seconds: 2);
const Duration videoCancellationTimeout = Duration(seconds: 3);
const Duration prideMediaCacheMaxAge = Duration(hours: 24);

@immutable
class PrideWidgetShareRequest {
  final Widget widget;
  final PrideExportRequest exportRequest;
  final String? text;
  final SharePayload? payload;
  final Future<void> Function()? onBeforeCapture;

  const PrideWidgetShareRequest({
    required this.widget,
    required this.exportRequest,
    this.text,
    this.payload,
    this.onBeforeCapture,
  });
}

class _OffstageCaptureJob<T> {
  final Widget widget;
  final Future<T> Function(GlobalKey boundaryKey) operation;
  final Future<void> Function()? onBeforeCapture;
  final VoidCallback? onCancel;

  const _OffstageCaptureJob({
    required this.widget,
    required this.operation,
    this.onBeforeCapture,
    this.onCancel,
  });
}

class _VideoExportAttempt {
  final PrideExportRequest request;
  final String sourceImagePath;
  final PrideVideoExportService videoExportService;
  final _VideoExportCancellation cancellation;

  const _VideoExportAttempt({
    required this.request,
    required this.sourceImagePath,
    required this.videoExportService,
    required this.cancellation,
  });
}

class _VideoExportCancellation {
  bool requested = false;
  bool exportStarted = false;
  Future<bool>? nativeCancellation;
  final Completer<void> _requestCompleter = Completer<void>();

  Future<void> get whenRequested => _requestCompleter.future;

  void request() {
    if (requested) return;
    requested = true;
    _requestCompleter.complete();
  }
}

class ShareCardCaptureService {
  final Stopwatch Function() _stopwatchFactory;

  const ShareCardCaptureService({
    Stopwatch Function() stopwatchFactory = Stopwatch.new,
  }) : _stopwatchFactory = stopwatchFactory;

  static final _analyticsService = AnalyticsService();
  static const _shareTextBuilder = PrideShareTextBuilder();
  static int _fileSequence = 0;

  Future<void> captureAndShare({
    required GlobalKey boundaryKey,
    required String fileName,
    String? text,
    SharePayload? payload,
    double pixelRatio = matchResultShareExportPixelRatio,
  }) async {
    final pngBytes = await captureBoundaryPng(
      boundaryKey: boundaryKey,
      pixelRatio: pixelRatio,
    );
    await persistAndSharePng(
      pngBytes: pngBytes,
      fileName: fileName,
      text: text,
      payload: payload,
    );
  }

  @protected
  Future<Uint8List> captureBoundaryPng({
    required GlobalKey boundaryKey,
    required double pixelRatio,
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
    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('تعذر إنشاء صورة المشاركة.');
      }
      return byteData.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  @protected
  Future<void> persistAndSharePng({
    required Uint8List pngBytes,
    required String fileName,
    String? text,
    SharePayload? payload,
  }) async {
    final file = await persistPngBytes(pngBytes: pngBytes, fileName: fileName);
    await sharePersistedFile(filePath: file.path, text: text, payload: payload);
  }

  @protected
  Future<File> persistPngBytes({
    required Uint8List pngBytes,
    required String fileName,
  }) async {
    final temporaryDirectory = await getTemporaryDirectory();
    final directory = Directory(
      '${temporaryDirectory.path}/pride_image_exports',
    );
    await directory.create(recursive: true);
    await _pruneExpiredPrideImages(directory);
    var safeFileName = fileName
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    if (safeFileName.isEmpty) safeFileName = 'el7reef_pride';
    if (safeFileName.length > 80) {
      safeFileName = safeFileName.substring(0, 80);
    }
    final uniqueSuffix =
        '${DateTime.now().microsecondsSinceEpoch}_${_fileSequence++}';
    final file = File('${directory.path}/${safeFileName}_$uniqueSuffix.png');
    await file.writeAsBytes(pngBytes, flush: true);
    return file;
  }

  Future<void> _pruneExpiredPrideImages(Directory directory) async {
    final cutoff = DateTime.now().subtract(prideMediaCacheMaxAge);
    try {
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File) continue;
        final modified = await entity.lastModified();
        if (modified.isBefore(cutoff)) _deleteFileSafely(entity);
      }
    } on FileSystemException catch (error, stackTrace) {
      AppLogger.error('PrideImageCache.prune', error, stackTrace);
    }
  }

  void _deleteFileSafely(File file) {
    try {
      if (file.existsSync()) file.deleteSync();
    } on FileSystemException catch (error, stackTrace) {
      AppLogger.error('PrideImageCache.delete', error, stackTrace);
    }
  }

  @protected
  Future<void> sharePersistedFile({
    required String filePath,
    String? text,
    SharePayload? payload,
  }) async {
    final shareText = _shareTextBuilder.build(
      baseText: text,
      payload: payload,
      includeGrowthLink: FeatureFlags.prideGrowthLinksEnabled,
    );
    if (payload != null) {
      _analyticsService.trackPrideCardViewed(payload);
      _analyticsService.trackShareStarted(payload);
    }
    await Share.shareXFiles([XFile(filePath)], text: shareText);
    if (payload != null) {
      _analyticsService.trackShareSheetReturned(payload);
    }
  }

  Future<PrideShareOutcome> exportAndShareWidget({
    required BuildContext context,
    required PrideWidgetShareRequest shareRequest,
    PrideVideoExportService videoExportService =
        const MethodChannelPrideVideoExportService(),
  }) async {
    final exportRequest = shareRequest.exportRequest;
    final cancellation = _VideoExportCancellation();
    if (exportRequest.mediaType == PrideMediaType.video &&
        !exportRequest.cardType.supportsVideoExport) {
      throw ArgumentError.value(
        exportRequest.cardType,
        'cardType',
        'This pride card does not support video export.',
      );
    }
    final stopwatch = _stopwatchFactory()..start();

    try {
      return await _runOffstageCapture(
        context: context,
        job: _OffstageCaptureJob(
          widget: shareRequest.widget,
          onBeforeCapture: shareRequest.onBeforeCapture,
          onCancel: exportRequest.mediaType == PrideMediaType.video
              ? () =>
                    _requestVideoCancellation(cancellation, videoExportService)
              : null,
          operation: (boundaryKey) => _exportAndShareBoundary(
            boundaryKey: boundaryKey,
            shareRequest: shareRequest,
            videoExportService: videoExportService,
            cancellation: cancellation,
            stopwatch: stopwatch,
          ),
        ),
      );
    } on Exception catch (error, stackTrace) {
      stopwatch.stop();
      AppLogger.error(
        'ShareCardCaptureService.exportAndShareWidget',
        error,
        stackTrace,
      );
      if (cancellation.requested) {
        final cancelledResult = _cancelledResult(
          exportRequest,
          stopwatch.elapsed,
        );
        _analyticsService.trackPrideExportFinished(cancelledResult);
        return PrideShareOutcome(
          exportResult: cancelledResult,
          sharedMediaType: null,
        );
      }
      final sharedFallback = await _shareTextFallback(
        text: shareRequest.text,
        payload: shareRequest.payload,
      );
      if (!sharedFallback) {
        Error.throwWithStackTrace(error, stackTrace);
      }
      final exportResult = PrideExportResult(
        request: exportRequest,
        filePath: null,
        exportDuration: stopwatch.elapsed,
        fallbackUsed: true,
        failureCode: 'media_preparation_failed',
      );
      _analyticsService.trackPrideExportFinished(exportResult);
      return PrideShareOutcome(
        exportResult: exportResult,
        sharedMediaType: null,
      );
    }
  }

  Future<PrideShareOutcome> _exportAndShareBoundary({
    required GlobalKey boundaryKey,
    required PrideWidgetShareRequest shareRequest,
    required PrideVideoExportService videoExportService,
    required _VideoExportCancellation cancellation,
    required Stopwatch stopwatch,
  }) async {
    final request = shareRequest.exportRequest;
    final pngBytes = await captureBoundaryPng(
      boundaryKey: boundaryKey,
      pixelRatio: request.format.exportPixelRatio,
    );
    final pngFile = await persistPngBytes(
      pngBytes: pngBytes,
      fileName: request.fileName,
    );

    if (request.mediaType == PrideMediaType.image) {
      stopwatch.stop();
      final exportResult = PrideExportResult(
        request: request,
        filePath: pngFile.path,
        exportDuration: stopwatch.elapsed,
      );
      await _sharePreparedFile(pngFile.path, shareRequest);
      _analyticsService.trackPrideExportFinished(exportResult);
      return PrideShareOutcome(
        exportResult: exportResult,
        sharedMediaType: PrideMediaType.image,
      );
    }

    final videoResult = await _exportVideoOrUnavailable(
      _VideoExportAttempt(
        request: request,
        sourceImagePath: pngFile.path,
        videoExportService: videoExportService,
        cancellation: cancellation,
      ),
    );
    stopwatch.stop();
    final measuredVideoResult = _withExportDuration(
      videoResult,
      stopwatch.elapsed,
    );
    if (measuredVideoResult.failureCode == 'export_cancelled') {
      if (!cancellation.exportStarted) {
        _deleteFileSafely(pngFile);
      } else {
        final nativeCancellation = cancellation.nativeCancellation;
        if (nativeCancellation != null) {
          unawaited(
            nativeCancellation.then((cancelled) {
              if (cancelled) _deleteFileSafely(pngFile);
            }),
          );
        }
      }
      _analyticsService.trackPrideExportFinished(measuredVideoResult);
      return PrideShareOutcome(
        exportResult: measuredVideoResult,
        sharedMediaType: null,
      );
    }
    if (measuredVideoResult.succeeded) {
      _deleteFileSafely(pngFile);
      await _sharePreparedFile(measuredVideoResult.filePath!, shareRequest);
      _analyticsService.trackPrideExportFinished(measuredVideoResult);
      return PrideShareOutcome(
        exportResult: measuredVideoResult,
        sharedMediaType: PrideMediaType.video,
      );
    }

    await _sharePreparedFile(pngFile.path, shareRequest);
    final fallbackResult = _imageFallbackResult(
      measuredVideoResult,
      pngFile.path,
    );
    _analyticsService.trackPrideExportFinished(fallbackResult);
    return PrideShareOutcome(
      exportResult: fallbackResult,
      sharedMediaType: PrideMediaType.image,
    );
  }

  PrideExportResult _withExportDuration(
    PrideExportResult result,
    Duration exportDuration,
  ) {
    return PrideExportResult(
      request: result.request,
      filePath: result.filePath,
      exportDuration: exportDuration,
      fallbackUsed: result.fallbackUsed,
      failureCode: result.failureCode,
    );
  }

  Future<PrideExportResult> _exportVideoOrUnavailable(
    _VideoExportAttempt attempt,
  ) async {
    if (attempt.cancellation.requested) {
      return _cancelledResult(attempt.request, Duration.zero);
    }
    if (!FeatureFlags.prideVideoExportEnabled) {
      return _videoUnavailableResult(
        attempt.request,
        Duration.zero,
        'flag_disabled',
      );
    }
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return _videoUnavailableResult(
        attempt.request,
        Duration.zero,
        'unsupported_platform',
      );
    }
    attempt.cancellation.exportStarted = true;
    final exportFuture = attempt.videoExportService.export(
      request: attempt.request,
      sourceImagePath: attempt.sourceImagePath,
    );
    final exportResult = await Future.any([
      exportFuture,
      attempt.cancellation.whenRequested.then(
        (_) => _cancelledResult(attempt.request, Duration.zero),
      ),
    ]);
    if (attempt.cancellation.requested &&
        exportResult.failureCode != 'export_cancelled') {
      return _cancelledResult(attempt.request, Duration.zero);
    }
    return exportResult;
  }

  PrideExportResult _videoUnavailableResult(
    PrideExportRequest request,
    Duration elapsed,
    String failureCode,
  ) {
    return PrideExportResult(
      request: request,
      filePath: null,
      exportDuration: elapsed,
      failureCode: failureCode,
    );
  }

  PrideExportResult _cancelledResult(
    PrideExportRequest request,
    Duration elapsed,
  ) {
    return PrideExportResult(
      request: request,
      filePath: null,
      exportDuration: elapsed,
      failureCode: 'export_cancelled',
    );
  }

  PrideExportResult _imageFallbackResult(
    PrideExportResult failedVideoResult,
    String pngPath,
  ) {
    return PrideExportResult(
      request: failedVideoResult.request,
      filePath: pngPath,
      exportDuration: failedVideoResult.exportDuration,
      fallbackUsed: true,
      failureCode: failedVideoResult.failureCode,
    );
  }

  void _requestVideoCancellation(
    _VideoExportCancellation cancellation,
    PrideVideoExportService videoExportService,
  ) {
    cancellation.request();
    if (cancellation.exportStarted && cancellation.nativeCancellation == null) {
      final nativeCancellation = _cancelVideoExport(videoExportService);
      cancellation.nativeCancellation = nativeCancellation;
      unawaited(nativeCancellation);
    }
  }

  Future<bool> _cancelVideoExport(
    PrideVideoExportService videoExportService,
  ) async {
    try {
      await videoExportService.cancel().timeout(videoCancellationTimeout);
      return true;
    } on PlatformException catch (error, stackTrace) {
      AppLogger.error('PrideVideoExport.cancel', error, stackTrace);
    } on MissingPluginException catch (error, stackTrace) {
      AppLogger.error('PrideVideoExport.cancel', error, stackTrace);
    } on TimeoutException catch (error, stackTrace) {
      AppLogger.error('PrideVideoExport.cancel', error, stackTrace);
    }
    return false;
  }

  Future<void> _sharePreparedFile(
    String filePath,
    PrideWidgetShareRequest request,
  ) {
    return sharePersistedFile(
      filePath: filePath,
      text: request.text,
      payload: request.payload,
    );
  }

  /// التقاط أي ودجت ومشاركتها عبر إدارتها في الـ Overlay
  Future<void> captureAndShareWidget({
    required BuildContext context,
    required Widget widget,
    required String fileName,
    String? text,
    SharePayload? payload,
    Future<void> Function()? onBeforeCapture,
  }) async {
    try {
      await _runOffstageCapture(
        context: context,
        job: _OffstageCaptureJob(
          widget: widget,
          onBeforeCapture: onBeforeCapture,
          operation: (boundaryKey) => captureAndShare(
            boundaryKey: boundaryKey,
            fileName: fileName,
            text: text,
            payload: payload,
          ),
        ),
      );
    } on Exception catch (error, stackTrace) {
      AppLogger.error(
        'ShareCardCaptureService.captureAndShareWidget',
        error,
        stackTrace,
      );
      final sharedFallback = await _shareTextFallback(
        text: text,
        payload: payload,
      );
      if (!sharedFallback) {
        Error.throwWithStackTrace(error, stackTrace);
      }
    }
  }

  Future<T> _runOffstageCapture<T>({
    required BuildContext context,
    required _OffstageCaptureJob<T> job,
  }) async {
    final boundaryKey = GlobalKey();
    final entry = _captureOverlayEntry(boundaryKey, job.widget);
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) throw Exception('تعذر تجهيز نافذة المشاركة.');
    final navigator = Navigator.of(context, rootNavigator: true);
    final progressRoute = _progressRoute(context, job.onCancel);
    unawaited(navigator.push(progressRoute));

    var inserted = false;
    try {
      overlay.insert(entry);
      inserted = true;
      await WidgetsBinding.instance.endOfFrame;
      if (job.onBeforeCapture != null) {
        await job.onBeforeCapture!().timeout(
          sharePreparationTimeout,
          onTimeout: () {},
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
      return await job.operation(boundaryKey);
    } finally {
      if (inserted) entry.remove();
      if (navigator.mounted && progressRoute.isActive) {
        navigator.removeRoute(progressRoute);
      }
    }
  }

  OverlayEntry _captureOverlayEntry(GlobalKey boundaryKey, Widget widget) {
    return OverlayEntry(
      builder: (_) => Positioned(
        left: 0,
        top: 0,
        child: IgnorePointer(
          child: Opacity(
            opacity: 0.01,
            child: RepaintBoundary(key: boundaryKey, child: widget),
          ),
        ),
      ),
    );
  }

  DialogRoute<void> _progressRoute(
    BuildContext context,
    VoidCallback? onCancel,
  ) {
    return DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: onCancel == null
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : _PrideVideoExportProgress(onCancel: onCancel),
      ),
    );
  }

  Future<bool> _shareTextFallback({String? text, SharePayload? payload}) async {
    final fallbackText = _shareTextBuilder.build(
      baseText: text ?? 'شوف لحظة الفخر دي على الحريف',
      payload: payload,
      includeGrowthLink: FeatureFlags.prideGrowthLinksEnabled,
    );
    if (fallbackText == null || fallbackText.trim().isEmpty) return false;

    if (payload != null) {
      _analyticsService.trackPrideCardViewed(payload);
      _analyticsService.trackShareStarted(payload);
    }
    await Share.share(fallbackText);
    if (payload != null) {
      _analyticsService.trackShareSheetReturned(payload);
    }
    return true;
  }
}

class _PrideVideoExportProgress extends StatefulWidget {
  final VoidCallback onCancel;

  const _PrideVideoExportProgress({required this.onCancel});

  @override
  State<_PrideVideoExportProgress> createState() =>
      _PrideVideoExportProgressState();
}

class _PrideVideoExportProgressState extends State<_PrideVideoExportProgress> {
  bool _cancelRequested = false;

  void _cancel() {
    setState(() => _cancelRequested = true);
    widget.onCancel();
  }

  @override
  Widget build(BuildContext context) {
    final statusText = _cancelRequested
        ? 'سيتم إغلاق النافذة فور إيقاف تجهيز الفيديو.'
        : 'سيتم فتح شاشة المشاركة بعد اكتمال التجهيز.';
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Semantics(
          liveRegion: true,
          child: Text(
            _cancelRequested ? 'جار إلغاء التصدير' : 'بنجهّز الفيديو',
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: AppDimensions.md),
            Text(statusText),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _cancelRequested ? null : _cancel,
            child: const Text('إلغاء التصدير'),
          ),
        ],
      ),
    );
  }
}
