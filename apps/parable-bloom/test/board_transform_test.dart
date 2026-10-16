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
