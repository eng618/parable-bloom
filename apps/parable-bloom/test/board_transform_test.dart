import 'package:flutter_test/flutter_test.dart';

import 'package:parable_bloom/core/board_transform.dart';
import 'package:parable_bloom/core/game_board_layout.dart';

void main() {
  group('BoardTransform', () {
    test('boardPosition centers the board without pan', () {
      final boardW = GameBoardLayout.boardWidth(4);
      final boardH = GameBoardLayout.boardHeight(4);

      final pos = BoardTransform.boardPosition(
        cols: 4,
        rows: 4,
        zoom: 1.0,
        panX: 0,
        panY: 0,
        screenWidth: 800,
        screenHeight: 600,
      );

      expect(pos.x, (800 - boardW) / 2);
      expect(pos.y, (600 - boardH) / 2);
    });

    test('boardPosition applies zoom and pan', () {
      final pos = BoardTransform.boardPosition(
        cols: 4,
        rows: 4,
        zoom: 2.0,
        panX: 10,
        panY: -5,
        screenWidth: 800,
        screenHeight: 600,
      );

      expect(pos.x, (800 - GameBoardLayout.boardWidth(4) * 2) / 2 + 10);
      expect(pos.y, (600 - GameBoardLayout.boardHeight(4) * 2) / 2 - 5);
    });

    test('panForAnchoredZoom with ratio 1 is a one-finger drag', () {
      final pan = BoardTransform.panForAnchoredZoom(
        zoom0: 1.4,
        panX0: 20,
        panY0: -8,
        zoom1: 1.4,
        focalX0: 100,
        focalY0: 220,
        focalX: 112,
        focalY: 213,
        screenWidth: 390,
        screenHeight: 844,
      );

      expect(pan.x, 32);
      expect(pan.y, -15);
    });

    test('stationary off-center pinch keeps the board point under the fingers',
        () {
      const cols = 6;
      const rows = 8;
      const screenWidth = 390.0;
      const screenHeight = 844.0;
      const zoom0 = 1.0;
      const panX0 = 12.0;
      const panY0 = -30.0;
      const focalX = 300.0;
      const focalY = 180.0;

      final origin0 = BoardTransform.boardPosition(
        cols: cols,
        rows: rows,
        zoom: zoom0,
        panX: panX0,
        panY: panY0,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
      );
      final localX = (focalX - origin0.x) / zoom0;
      final localY = (focalY - origin0.y) / zoom0;

      const zoom1 = 2.0;
      final pan = BoardTransform.panForAnchoredZoom(
        zoom0: zoom0,
        panX0: panX0,
        panY0: panY0,
        zoom1: zoom1,
        focalX0: focalX,
        focalY0: focalY,
        focalX: focalX,
        focalY: focalY,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
      );
      final origin1 = BoardTransform.boardPosition(
        cols: cols,
        rows: rows,
        zoom: zoom1,
        panX: pan.x,
        panY: pan.y,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
      );

      expect(origin1.x + localX * zoom1, closeTo(focalX, 0.001));
      expect(origin1.y + localY * zoom1, closeTo(focalY, 0.001));
    });

    test('pinch-drag lands the original board point on the new focal point',
        () {
      const cols = 6;
      const rows = 8;
      const screenWidth = 390.0;
      const screenHeight = 844.0;
      const zoom0 = 1.2;
      const panX0 = -16.0;
      const panY0 = 24.0;
      const focalX0 = 80.0;
      const focalY0 = 640.0;
      const focalX = 140.0;
      const focalY = 590.0;

      final origin0 = BoardTransform.boardPosition(
        cols: cols,
        rows: rows,
        zoom: zoom0,
        panX: panX0,
        panY: panY0,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
      );
      final localX = (focalX0 - origin0.x) / zoom0;
      final localY = (focalY0 - origin0.y) / zoom0;

      const zoom1 = 1.8;
      final pan = BoardTransform.panForAnchoredZoom(
        zoom0: zoom0,
        panX0: panX0,
        panY0: panY0,
        zoom1: zoom1,
        focalX0: focalX0,
        focalY0: focalY0,
        focalX: focalX,
        focalY: focalY,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
      );
      final origin1 = BoardTransform.boardPosition(
        cols: cols,
        rows: rows,
        zoom: zoom1,
        panX: pan.x,
        panY: pan.y,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
      );

      expect(origin1.x + localX * zoom1, closeTo(focalX, 0.001));
      expect(origin1.y + localY * zoom1, closeTo(focalY, 0.001));
    });

    test('center pinch scales an existing pan and holds the center point', () {
      const cols = 4;
      const rows = 4;
      const screenWidth = 400.0;
      const screenHeight = 800.0;
      const zoom0 = 1.0;
      const panX0 = 50.0;
      const panY0 = -30.0;
      const focalX = screenWidth / 2;
      const focalY = screenHeight / 2;

      final origin0 = BoardTransform.boardPosition(
        cols: cols,
        rows: rows,
        zoom: zoom0,
        panX: panX0,
        panY: panY0,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
      );
      final localX = (focalX - origin0.x) / zoom0;
      final localY = (focalY - origin0.y) / zoom0;

      const zoom1 = 2.0;
      final pan = BoardTransform.panForAnchoredZoom(
        zoom0: zoom0,
        panX0: panX0,
        panY0: panY0,
        zoom1: zoom1,
        focalX0: focalX,
        focalY0: focalY,
        focalX: focalX,
        focalY: focalY,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
      );

      expect(pan.x, closeTo(panX0 * zoom1 / zoom0, 0.001));
      expect(pan.y, closeTo(panY0 * zoom1 / zoom0, 0.001));

      final origin1 = BoardTransform.boardPosition(
        cols: cols,
        rows: rows,
        zoom: zoom1,
        panX: pan.x,
        panY: pan.y,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
      );
      expect(origin1.x + localX * zoom1, closeTo(focalX, 0.001));
      expect(origin1.y + localY * zoom1, closeTo(focalY, 0.001));
    });

    test('cellCenter matches manual grid math (y=0 at bottom)', () {
      const zoom = 1.5;
      const boardX = 100.0;
      const boardY = 50.0;

      final center = BoardTransform.cellCenter(
        x: 2,
        y: 1,
        gridHeight: 4,
        zoom: zoom,
        boardX: boardX,
        boardY: boardY,
      );

      final visualRow = 4 - 1 - 1;
      expect(center.x, boardX + GameBoardLayout.cellCenterX(2) * zoom);
      expect(center.y, boardY + GameBoardLayout.cellCenterY(visualRow) * zoom);
    });

    group('projectToViewportEdge', () {
      test('each direction reaches its viewport edge', () {
        const l = 0.0, t = 0.0, r = 800.0, b = 600.0;

        var p = BoardTransform.projectToViewportEdge(
          headX: 100,
          headY: 100,
          direction: 'right',
          left: l,
          top: t,
          right: r,
          bottom: b,
        )!;
        expect(p.x, r);
        expect(p.y, 100);

        p = BoardTransform.projectToViewportEdge(
          headX: 100,
          headY: 100,
          direction: 'left',
          left: l,
          top: t,
          right: r,
          bottom: b,
        )!;
        expect(p.x, l);
        expect(p.y, 100);

        p = BoardTransform.projectToViewportEdge(
          headX: 100,
          headY: 100,
          direction: 'down',
          left: l,
          top: t,
          right: r,
          bottom: b,
        )!;
        expect(p.x, 100);
        expect(p.y, b);

        p = BoardTransform.projectToViewportEdge(
          headX: 100,
          headY: 100,
          direction: 'up',
          left: l,
          top: t,
          right: r,
          bottom: b,
        )!;
        expect(p.x, 100);
        expect(p.y, t);
      });

      test('overshoot pushes past the edge for round-cap bleed', () {
        final p = BoardTransform.projectToViewportEdge(
          headX: 100,
          headY: 100,
          direction: 'right',
          left: 0,
          top: 0,
          right: 800,
          bottom: 600,
          overshoot: 6,
        )!;
        expect(p.x, 806);
        expect(p.y, 100);
      });

      test('head past the edge in ray direction returns null', () {
        expect(
          BoardTransform.projectToViewportEdge(
            headX: 900,
            headY: 100,
            direction: 'right',
            left: 0,
            top: 0,
            right: 800,
            bottom: 600,
          ),
          isNull,
        );
        expect(
          BoardTransform.projectToViewportEdge(
            headX: 100,
            headY: -10,
            direction: 'up',
            left: 0,
            top: 0,
            right: 800,
            bottom: 600,
          ),
          isNull,
        );
      });

      test('unknown direction returns null', () {
        expect(
          BoardTransform.projectToViewportEdge(
            headX: 100,
            headY: 100,
            direction: 'diagonal',
            left: 0,
            top: 0,
            right: 800,
            bottom: 600,
          ),
          isNull,
        );
      });
    });
  });
}
