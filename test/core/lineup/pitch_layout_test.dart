import 'package:el7reef/core/lineup/pitch_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('11-player layout keeps dense nodes and editor hit targets', () {
    final layout = ProfessionalPitchLayoutMetrics.calculate(
      width: 320,
      playerCount: 11,
      presentationMode: false,
      editorMode: true,
    );

    expect(layout.denseSquad, isTrue);
    expect(layout.compact, isTrue);
    expect(layout.height, 496);
    expect(layout.nodeWidth, 48);
    expect(layout.nodeHeight, 76);
    expect(layout.hitWidth, 60);
    expect(layout.hitHeight, 88);
  });

  test('pitch projection expands formation rows over the usable height', () {
    final top = PitchLayout.project(
      x: 50,
      y: 20,
      width: 320,
      height: 500,
      minY: 20,
      maxY: 80,
      expandVertical: true,
    );
    final bottom = PitchLayout.project(
      x: 50,
      y: 80,
      width: 320,
      height: 500,
      minY: 20,
      maxY: 80,
      expandVertical: true,
    );

    expect(top.dx, 160);
    expect(top.dy, 85);
    expect(bottom.dx, 160);
    expect(bottom.dy, 435);
  });

  test('share player coordinates stay inside both card edges', () {
    expect(
      PitchLayout.positionedCoordinate(
        percentage: -20,
        totalExtent: 360,
        childExtent: 80,
      ),
      2,
    );
    expect(
      PitchLayout.positionedCoordinate(
        percentage: 120,
        totalExtent: 360,
        childExtent: 80,
      ),
      278,
    );
  });
}
