import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:el7reef/core/services/feature_flag_service.dart';
import 'package:el7reef/data/repositories/player_repository_impl.dart';
import 'package:el7reef/domain/entities/participant_ref.dart';
import 'package:el7reef/domain/entities/player.dart';
import 'package:el7reef/domain/entities/share_payload.dart';
import 'package:el7reef/features/shareables/models/pride_card_format.dart';
import 'package:el7reef/features/shareables/models/pride_export.dart';
import 'package:el7reef/features/shareables/services/pride_identity_image_resolver.dart';
import 'package:el7reef/features/shareables/services/pride_video_export_service.dart';
import 'package:el7reef/features/shareables/services/share_card_capture_service.dart';
import 'package:el7reef/features/shareables/widgets/pride_card_shell.dart';

void main() {
  testWidgets('slow identity lookup returns the initials fallback on time', (
    tester,
  ) async {
    final resolver = PrideIdentityImageResolver(
      playerRepository: _NeverCompletingPlayerRepository(),
    );
    final lookup = resolver.imageUrlsFor(const [
      ParticipantRef(
        kind: ParticipantRefKind.player,
        id: 'player-1',
        displayName: 'لاعب',
      ),
    ]);

    await tester.pump(prideIdentityLookupTimeout);

    expect(await lookup, {'player:player-1': null});
  });

  testWidgets('returning from share removes only its loading dialog', (
    tester,
  ) async {
    final shareReturn = Completer<void>();
    final service = _ControlledCaptureService(shareReturn.future);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () {
                unawaited(
                  service.captureAndShareWidget(
                    context: context,
                    widget: const SizedBox(
                      width: 120,
                      height: 120,
                      child: ColoredBox(color: Colors.green),
                    ),
                    fileName: 'slow-share',
                    onBeforeCapture: () => Completer<void>().future,
                  ),
                );
              },
              child: const Text('المباراة'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('المباراة'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(sharePreparationTimeout);
    await tester.pump(const Duration(milliseconds: 100));
    expect(service.captureCount, 1);

    shareReturn.complete();
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('المباراة'), findsOneWidget);
  });

  for (final format in PrideCardFormat.values) {
    testWidgets('capture keeps the exact ${format.name} export dimensions', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = _DimensionCaptureService();
      final boundaryKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: boundaryKey,
                child: PrideCardShell(
                  exportMode: true,
                  format: format,
                  semanticsLabel: 'بطاقة اختبار',
                  child: const ColoredBox(color: Colors.green),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.runAsync(
        () => service.captureAndShare(
          boundaryKey: boundaryKey,
          fileName: 'format-${format.name}',
          pixelRatio: format.exportPixelRatio,
        ),
      );

      expect(
        service.capturedPixels,
        Size(format.exportWidth.toDouble(), format.exportHeight.toDouble()),
      );
    });
  }

  testWidgets('offscreen export keeps landscape width on a 360dp host', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _BoundarySizeCaptureService();
    late Future<void> captureFuture;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () {
                captureFuture = service.captureAndShareWidget(
                  context: context,
                  widget: const PrideCardShell(
                    exportMode: true,
                    format: PrideCardFormat.landscape16x9,
                    semanticsLabel: 'بطاقة أفقية',
                    child: ColoredBox(color: Colors.green),
                  ),
                  fileName: 'landscape-layout',
                );
              },
              child: const Text('صدّر أفقي'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('صدّر أفقي'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await captureFuture;
    await tester.pumpAndSettle();

    expect(service.logicalSize, const Size(640, 360));
  });

  testWidgets('encoder failure opens the share sheet with the PNG fallback', (
    tester,
  ) async {
    _enableAndroidVideoExport();
    final captureService = _MediaCaptureService();
    late Future<PrideShareOutcome> shareFuture;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () {
                shareFuture = captureService.exportAndShareWidget(
                  context: context,
                  shareRequest: _videoShareRequest(),
                  videoExportService: const _FakeVideoExportService(
                    failureCode: 'encoder_failed',
                  ),
                );
              },
              child: const Text('جهّز الفيديو'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('جهّز الفيديو'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final outcome = await shareFuture;
    await tester.pumpAndSettle();

    expect(outcome.usedImageFallback, isTrue);
    expect(outcome.exportResult.failureCode, 'encoder_failed');
    expect(captureService.sharedPaths, ['/tmp/el7reef-result.png']);
  });

  testWidgets('successful encoder output opens the share sheet with MP4', (
    tester,
  ) async {
    _enableAndroidVideoExport();
    final sourcePng = _createTemporaryPng();
    final captureService = _MediaCaptureService(persistedPng: sourcePng);
    late Future<PrideShareOutcome> shareFuture;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () {
                shareFuture = captureService.exportAndShareWidget(
                  context: context,
                  shareRequest: _videoShareRequest(),
                  videoExportService: const _FakeVideoExportService(),
                );
              },
              child: const Text('جهّز الفيديو'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('جهّز الفيديو'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final outcome = await shareFuture;
    await tester.pumpAndSettle();

    expect(outcome.usedImageFallback, isFalse);
    expect(outcome.sharedMediaType, PrideMediaType.video);
    expect(outcome.exportResult.exportDuration, greaterThan(Duration.zero));
    expect(captureService.sharedPaths, ['/tmp/el7reef-result.mp4']);
    expect(sourcePng.existsSync(), isFalse);
  });

  testWidgets('export duration includes capture, persistence and encoding', (
    tester,
  ) async {
    _enableAndroidVideoExport();
    final stopwatch = _ControlledStopwatch();
    final captureService = _TimingCaptureService(stopwatch);
    final videoExportService = _TimingVideoExportService(stopwatch);
    late Future<PrideShareOutcome> shareFuture;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () {
                shareFuture = captureService.exportAndShareWidget(
                  context: context,
                  shareRequest: _videoShareRequest(),
                  videoExportService: videoExportService,
                );
              },
              child: const Text('جهّز الفيديو'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('جهّز الفيديو'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final outcome = await shareFuture;
    await tester.pumpAndSettle();

    expect(outcome.exportResult.exportDuration, const Duration(seconds: 6));
    expect(outcome.sharedMediaType, PrideMediaType.video);
  });

  testWidgets('cancel before encoder start does not export or share', (
    tester,
  ) async {
    _enableAndroidVideoExport();
    final captureGate = Completer<void>();
    final captureService = _MediaCaptureService();
    final videoExportService = _ControllableVideoExportService();
    late Future<PrideShareOutcome> shareFuture;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () {
                shareFuture = captureService.exportAndShareWidget(
                  context: context,
                  shareRequest: _videoShareRequest(
                    onBeforeCapture: () => captureGate.future,
                  ),
                  videoExportService: videoExportService,
                );
              },
              child: const Text('جهّز الفيديو'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('جهّز الفيديو'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('إلغاء التصدير'));
    captureGate.complete();
    await tester.pump(const Duration(milliseconds: 100));
    final outcome = await shareFuture;
    await tester.pumpAndSettle();

    expect(outcome.cancelled, isTrue);
    expect(outcome.exportResult.fallbackUsed, isFalse);
    expect(videoExportService.exportCalls, 0);
    expect(videoExportService.cancelCalls, 0);
    expect(captureService.sharedPaths, isEmpty);
  });

  testWidgets('cancel during encoder stops export without fallback sharing', (
    tester,
  ) async {
    _enableAndroidVideoExport();
    final sourcePng = _createTemporaryPng();
    final captureService = _MediaCaptureService(persistedPng: sourcePng);
    final videoExportService = _ControllableVideoExportService();
    late Future<PrideShareOutcome> shareFuture;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () {
                shareFuture = captureService.exportAndShareWidget(
                  context: context,
                  shareRequest: _videoShareRequest(),
                  videoExportService: videoExportService,
                );
              },
              child: const Text('جهّز الفيديو'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('جهّز الفيديو'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(videoExportService.exportCalls, 1);
    await tester.tap(find.text('إلغاء التصدير'));
    await tester.pump();
    final outcome = await shareFuture;
    await tester.pumpAndSettle();

    expect(outcome.cancelled, isTrue);
    expect(outcome.usedImageFallback, isFalse);
    expect(outcome.usedTextFallback, isFalse);
    expect(videoExportService.cancelCalls, 1);
    expect(captureService.sharedPaths, isEmpty);
    expect(sourcePng.existsSync(), isFalse);
  });

  testWidgets('system back cannot hide an active video export', (tester) async {
    _enableAndroidVideoExport();
    final captureService = _MediaCaptureService();
    final videoExportService = _ControllableVideoExportService();
    late Future<PrideShareOutcome> shareFuture;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () {
                shareFuture = captureService.exportAndShareWidget(
                  context: context,
                  shareRequest: _videoShareRequest(),
                  videoExportService: videoExportService,
                );
              },
              child: const Text('جهّز الفيديو'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('جهّز الفيديو'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('بنجهّز الفيديو'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(find.text('بنجهّز الفيديو'), findsOneWidget);
    await tester.tap(find.text('إلغاء التصدير'));
    await tester.pump();
    final outcome = await shareFuture;
    await tester.pumpAndSettle();
    expect(outcome.cancelled, isTrue);
  });

  testWidgets('hung native cancellation still closes progress immediately', (
    tester,
  ) async {
    _enableAndroidVideoExport();
    final captureService = _MediaCaptureService();
    final videoExportService = _HungVideoExportService();
    late Future<PrideShareOutcome> shareFuture;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () {
                shareFuture = captureService.exportAndShareWidget(
                  context: context,
                  shareRequest: _videoShareRequest(),
                  videoExportService: videoExportService,
                );
              },
              child: const Text('جهّز الفيديو'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('جهّز الفيديو'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(find.text('إلغاء التصدير'));
    await tester.pump();
    final outcome = await shareFuture;
    await tester.pumpAndSettle();

    expect(outcome.cancelled, isTrue);
    expect(videoExportService.cancelCalls, 1);
    expect(captureService.sharedPaths, isEmpty);
    expect(find.text('بنجهّز الفيديو'), findsNothing);

    await tester.pump(videoCancellationTimeout);
    await tester.pump();
  });
}

void _enableAndroidVideoExport() {
  Get.put(
    FeatureFlagService(
      overrides: {FeatureFlagKey.prideVideoExportEnabled: true},
    ),
  );
  addTearDown(() {
    Get.reset();
  });
}

PrideWidgetShareRequest _videoShareRequest({
  Future<void> Function()? onBeforeCapture,
}) {
  return PrideWidgetShareRequest(
    widget: const SizedBox(
      width: 360,
      height: 640,
      child: ColoredBox(color: Colors.green),
    ),
    exportRequest: const PrideExportRequest(
      cardType: ShareCardType.matchResult,
      format: PrideCardFormat.story9x16,
      mediaType: PrideMediaType.video,
      fileName: 'el7reef-result',
    ),
    onBeforeCapture: onBeforeCapture,
  );
}

File _createTemporaryPng() {
  final directory = Directory.systemTemp.createTempSync('el7reef_pride_test_');
  addTearDown(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });
  return File('${directory.path}/source.png')..writeAsBytesSync([1, 2, 3]);
}

class _NeverCompletingPlayerRepository extends PlayerRepositoryImpl {
  _NeverCompletingPlayerRepository()
    : super(firestore: FakeFirebaseFirestore());

  @override
  Future<Player?> getPlayer(String playerId) => Completer<Player?>().future;
}

class _ControlledCaptureService extends ShareCardCaptureService {
  final Future<void> shareReturn;
  int captureCount = 0;

  _ControlledCaptureService(this.shareReturn);

  @override
  Future<void> captureAndShare({
    required GlobalKey boundaryKey,
    required String fileName,
    String? text,
    SharePayload? payload,
    double pixelRatio = matchResultShareExportPixelRatio,
  }) {
    captureCount += 1;
    return shareReturn;
  }
}

class _DimensionCaptureService extends ShareCardCaptureService {
  Size? capturedPixels;

  @override
  Future<void> persistAndSharePng({
    required Uint8List pngBytes,
    required String fileName,
    String? text,
    SharePayload? payload,
  }) async {
    final header = ByteData.sublistView(pngBytes);
    capturedPixels = Size(
      header.getUint32(16).toDouble(),
      header.getUint32(20).toDouble(),
    );
  }
}

class _BoundarySizeCaptureService extends ShareCardCaptureService {
  Size? logicalSize;

  @override
  Future<void> captureAndShare({
    required GlobalKey boundaryKey,
    required String fileName,
    String? text,
    SharePayload? payload,
    double pixelRatio = matchResultShareExportPixelRatio,
  }) async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    logicalSize = boundary.size;
  }
}

class _MediaCaptureService extends ShareCardCaptureService {
  final List<String> sharedPaths = [];
  final File? persistedPng;

  _MediaCaptureService({this.persistedPng});

  @override
  Future<Uint8List> captureBoundaryPng({
    required GlobalKey boundaryKey,
    required double pixelRatio,
  }) async {
    return Uint8List.fromList([1, 2, 3]);
  }

  @override
  Future<File> persistPngBytes({
    required Uint8List pngBytes,
    required String fileName,
  }) async {
    return persistedPng ?? File('/tmp/el7reef-result.png');
  }

  @override
  Future<void> sharePersistedFile({
    required String filePath,
    String? text,
    SharePayload? payload,
  }) async {
    sharedPaths.add(filePath);
  }
}

class _TimingCaptureService extends ShareCardCaptureService {
  final _ControlledStopwatch stopwatch;

  _TimingCaptureService(this.stopwatch)
    : super(stopwatchFactory: () => stopwatch);

  @override
  Future<Uint8List> captureBoundaryPng({
    required GlobalKey boundaryKey,
    required double pixelRatio,
  }) async {
    stopwatch.advance(const Duration(seconds: 1));
    return Uint8List.fromList([1, 2, 3]);
  }

  @override
  Future<File> persistPngBytes({
    required Uint8List pngBytes,
    required String fileName,
  }) async {
    stopwatch.advance(const Duration(seconds: 2));
    return File('/tmp/el7reef-timing.png');
  }

  @override
  Future<void> sharePersistedFile({
    required String filePath,
    String? text,
    SharePayload? payload,
  }) async {}
}

class _TimingVideoExportService implements PrideVideoExportService {
  final _ControlledStopwatch stopwatch;

  const _TimingVideoExportService(this.stopwatch);

  @override
  Future<PrideExportResult> export({
    required PrideExportRequest request,
    required String sourceImagePath,
  }) async {
    stopwatch.advance(const Duration(seconds: 3));
    return PrideExportResult(
      request: request,
      filePath: '/tmp/el7reef-timing.mp4',
      exportDuration: const Duration(seconds: 3),
    );
  }

  @override
  Future<void> cancel() async {}
}

class _ControlledStopwatch extends Stopwatch {
  Duration _controlledElapsed = Duration.zero;
  bool _controlledRunning = false;

  void advance(Duration duration) {
    if (_controlledRunning) _controlledElapsed += duration;
  }

  @override
  void start() => _controlledRunning = true;

  @override
  void stop() => _controlledRunning = false;

  @override
  Duration get elapsed => _controlledElapsed;
}

class _FakeVideoExportService implements PrideVideoExportService {
  final String? failureCode;

  const _FakeVideoExportService({this.failureCode});

  @override
  Future<PrideExportResult> export({
    required PrideExportRequest request,
    required String sourceImagePath,
  }) async {
    return PrideExportResult(
      request: request,
      filePath: failureCode == null ? '/tmp/el7reef-result.mp4' : null,
      exportDuration: Duration.zero,
      failureCode: failureCode,
    );
  }

  @override
  Future<void> cancel() async {}
}

class _ControllableVideoExportService implements PrideVideoExportService {
  final Completer<PrideExportResult> _exportCompleter = Completer();
  PrideExportRequest? _request;
  int exportCalls = 0;
  int cancelCalls = 0;

  @override
  Future<PrideExportResult> export({
    required PrideExportRequest request,
    required String sourceImagePath,
  }) {
    exportCalls += 1;
    _request = request;
    return _exportCompleter.future;
  }

  @override
  Future<void> cancel() async {
    cancelCalls += 1;
    if (!_exportCompleter.isCompleted) {
      _exportCompleter.complete(
        PrideExportResult(
          request: _request!,
          filePath: null,
          exportDuration: const Duration(milliseconds: 200),
          failureCode: 'export_cancelled',
        ),
      );
    }
  }
}

class _HungVideoExportService implements PrideVideoExportService {
  final Completer<PrideExportResult> _exportCompleter = Completer();
  final Completer<void> _cancelCompleter = Completer();
  int cancelCalls = 0;

  @override
  Future<PrideExportResult> export({
    required PrideExportRequest request,
    required String sourceImagePath,
  }) {
    return _exportCompleter.future;
  }

  @override
  Future<void> cancel() {
    cancelCalls += 1;
    return _cancelCompleter.future;
  }
}
