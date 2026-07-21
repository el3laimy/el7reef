enum PrideCardFormat {
  square1x1(width: 360, height: 360, exportWidth: 1080, exportHeight: 1080),
  feed4x5(width: 360, height: 450),
  story9x16(width: 360, height: 640, exportWidth: 1080, exportHeight: 1920),
  landscape16x9(width: 640, height: 360, exportWidth: 1920, exportHeight: 1080);

  final double width;
  final double height;
  final int exportWidth;
  final int exportHeight;

  const PrideCardFormat({
    required this.width,
    required this.height,
    this.exportWidth = 1080,
    this.exportHeight = 1350,
  });

  double get aspectRatio => width / height;
  double get exportPixelRatio => exportWidth / width;
  bool get isLandscape => width > height;
  bool get isStory => this == PrideCardFormat.story9x16;
}
