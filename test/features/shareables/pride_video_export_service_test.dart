import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/domain/entities/share_payload.dart';
import 'package:el7reef/features/shareables/models/pride_card_format.dart';
import 'package:el7reef/features/shareables/models/pride_export.dart';
import 'package:el7reef/features/shareables/services/pride_video_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.el7reef.app/pride_video_export');
  const service = MethodChannelPrideVideoExportService();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('Android export bridge sends the stable Media3 contract', () async {
    MethodCall? receivedCall;
    messenger.setMockMethodCallHandler(channel, (call) async {
      receivedCall = call;
      return '/tmp/el7reef-result.mp4';
    });

    final exportResult = await service.export(
      request: _videoRequest(includeAudio: true),
      sourceImagePath: '/tmp/el7reef-result.png',
    );

    expect(exportResult.succeeded, isTrue);
    expect(exportResult.filePath, '/tmp/el7reef-result.mp4');
    expect(receivedCall?.method, 'export');
    expect(receivedCall?.arguments, {
      'sourceImagePath': '/tmp/el7reef-result.png',
      'outputFileName': 'el7reef-result',
      'width': 1080,
      'height': 1920,
      'durationMs': 6000,
      'frameRate': 30,
      'cardType': 'matchResult',
      'includeAudio': true,
    });
  });

  test(
    'encoder failure remains raw until the caller shares a fallback',
    () async {
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(code: 'encoder_failed');
      });

      final exportResult = await service.export(
        request: _videoRequest(includeAudio: false),
        sourceImagePath: '/tmp/el7reef-result.png',
      );

      expect(exportResult.succeeded, isFalse);
      expect(exportResult.fallbackUsed, isFalse);
      expect(exportResult.failureCode, 'encoder_failed');
    },
  );

  test(
    'empty native output cannot be reported as a successful video',
    () async {
      messenger.setMockMethodCallHandler(channel, (_) async => '  ');

      final exportResult = await service.export(
        request: _videoRequest(includeAudio: false),
        sourceImagePath: '/tmp/el7reef-result.png',
      );

      expect(exportResult.succeeded, isFalse);
      expect(exportResult.fallbackUsed, isFalse);
      expect(exportResult.failureCode, 'empty_output');
    },
  );

  test('cancel forwards to the native exporter', () async {
    String? receivedMethod;
    messenger.setMockMethodCallHandler(channel, (call) async {
      receivedMethod = call.method;
      return null;
    });

    await service.cancel();

    expect(receivedMethod, 'cancel');
  });

  test('hung encoder is cancelled and reported as a timeout', () async {
    final exportCompleter = Completer<String?>();
    final cancelCompleter = Completer<void>();
    final receivedMethods = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) {
      receivedMethods.add(call.method);
      if (call.method == 'export') return exportCompleter.future;
      return cancelCompleter.future;
    });
    const timeoutService = MethodChannelPrideVideoExportService(
      exportTimeout: Duration(milliseconds: 1),
      cancelTimeout: Duration(milliseconds: 1),
    );

    final exportResult = await timeoutService.export(
      request: _videoRequest(includeAudio: false),
      sourceImagePath: '/tmp/el7reef-result.png',
    );

    expect(exportResult.succeeded, isFalse);
    expect(exportResult.fallbackUsed, isFalse);
    expect(exportResult.failureCode, 'encoder_timeout');
    expect(receivedMethods, ['export', 'cancel']);
  });

  test('video policy stays limited to the approved pride families', () {
    expect(prideVideoSupportedCardTypes, {
      ShareCardType.matchResult,
      ShareCardType.mvp,
      ShareCardType.goalScorer,
      ShareCardType.qualification,
      ShareCardType.champion,
      ShareCardType.playerMilestone,
    });
    expect(ShareCardType.lineup.supportsVideoExport, isFalse);
    expect(ShareCardType.topScorers.supportsVideoExport, isFalse);
  });
}

PrideExportRequest _videoRequest({required bool includeAudio}) {
  return PrideExportRequest(
    cardType: ShareCardType.matchResult,
    format: PrideCardFormat.story9x16,
    mediaType: PrideMediaType.video,
    fileName: 'el7reef-result',
    includeAudio: includeAudio,
  );
}
