import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const prideCardTestFontFamily = 'PrideArabicTest';

Future<void> loadPrideCardTestFont() async {
  final loader = FontLoader(prideCardTestFontFamily);
  loader.addFont(
    File('assets/fonts/Cairo-Variable.ttf').readAsBytes().then(
      (bytes) =>
          bytes.buffer.asByteData(bytes.offsetInBytes, bytes.lengthInBytes),
    ),
  );
  await loader.load();
}

ThemeData prideCardTestTheme() => ThemeData(
  fontFamily: prideCardTestFontFamily,
  fontFamilyFallback: const <String>['Noto Sans Arabic'],
);
