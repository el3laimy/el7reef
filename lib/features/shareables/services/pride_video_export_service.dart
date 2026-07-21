import 'dart:async';

import 'package:flutter/services.dart';

import '../../../core/utils/app_logger.dart';
import '../models/pride_export.dart';

abstract interface class PrideVideoExportService {
  Future<PrideExportResult> export({
    required PrideExportRequest request,
    required String sourceImagePath,
  });

  Future<void> cancel();
}

/// Android-only bridge. The feature remains gated until the native encoder and
/// original sonic sting have passed device QA. Callers must fall back to PNG
/// when this bridge reports an unavailable or failed export.
class MethodChannelPrideVideoExportService implements PrideVideoExportService {
  static const MethodChannel _channel = MethodChannel(
    'com.el7reef.app/pride_video_export',
  );

  final Duration exportTimeout;
  final Duration cancelTimeout;

  const MethodChannelPrideVideoExportService({
    this.exportTimeout = const Duration(seconds: 30),
    this.cancelTimeout = const Duration(seconds: 3),
  });

  @override
  Future<PrideExportResult> export({
    required PrideExportRequest request,
    required String sourceImagePath,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final returnedPath = await _channel
          .invokeMethod<String>('export', {
            'sourceImagePath': sourceImagePath,
            'outputFileName': request.fileName,
            'width': request.format.exportWidth,
            'height': request.format.exportHeight,
            'durationMs': 6000,
            'frameRate': 30,
            'cardType': request.cardType.name,
            'includeAudio': request.includeAudio,
          })
          .timeout(exportTimeout);
      final path = returnedPath?.trim();
      final hasOutput = path != null && path.isNotEmpty;
      return PrideExportResult(
        request: request,
        filePath: hasOutput ? path : null,
        exportDuration: stopwatch.elapsed,
        failureCode: hasOutput ? null : 'empty_output',
      );
    } on PlatformException catch (error) {
      return PrideExportResult(
        request: request,
        filePath: null,
        exportDuration: stopwatch.elapsed,
        failureCode: error.code,
      );
    } on MissingPluginException {
      return PrideExportResult(
        request: request,
        filePath: null,
        exportDuration: stopwatch.elapsed,
        failureCode: 'encoder_unavailable',
      );
    } on TimeoutException catch (error, stackTrace) {
      AppLogger.error('PrideVideoExport.timeout', error, stackTrace);
      await _cancelAfterTimeout();
      return PrideExportResult(
        request: request,
        filePath: null,
        exportDuration: stopwatch.elapsed,
        failureCode: 'encoder_timeout',
      );
    } finally {
      stopwatch.stop();
    }
  }

  @override
  Future<void> cancel() =>
      _channel.invokeMethod<void>('cancel').timeout(cancelTimeout);

  Future<void> _cancelAfterTimeout() async {
    try {
      await cancel();
    } on PlatformException catch (error, stackTrace) {
      AppLogger.error('PrideVideoExport.timeoutCancel', error, stackTrace);
    } on MissingPluginException catch (error, stackTrace) {
      AppLogger.error('PrideVideoExport.timeoutCancel', error, stackTrace);
    } on TimeoutException catch (error, stackTrace) {
      AppLogger.error('PrideVideoExport.timeoutCancel', error, stackTrace);
    }
  }
}
