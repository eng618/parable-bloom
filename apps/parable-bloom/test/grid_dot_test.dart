import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/core/app_theme.dart';
import 'package:parable_bloom/core/game_board_layout.dart';
import 'package:parable_bloom/features/game/domain/entities/level_data.dart';
import 'package:parable_bloom/features/game/presentation/widgets/game_event_sink.dart';
import 'package:parable_bloom/features/game/presentation/widgets/garden_game.dart';
import 'package:parable_bloom/features/game/presentation/widgets/grid_component.dart';
import 'package:parable_bloom/features/game/presentation/widgets/grid_dot_pulse.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_dot_reveal.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_track.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const cream = Color(0xFFF9F3E5);
  const soil = Color(0xFF141914);

  group('grid dot theme', () {
    test('light and dark dots are different and readable on their grounds', () {
      expect(AppTheme.gridDotLight, const Color(0x8C2A3328));
      expect(AppTheme.gridDotDark, const Color(0x26E2D6C4));
      expect(AppTheme.getGridDotColor(Brightness.light), AppTheme.gridDotLight);
      expect(AppTheme.getGridDotColor(Brightness.dark), AppTheme.gridDotDark);
      expect(
        AppTheme.lightTheme.extension<AppThemeExtension>()!.gridDot,
        AppTheme.gridDotLight,
      );
      expect(
        AppTheme.darkTheme.extension<AppThemeExtension>()!.gridDot,
        AppTheme.gridDotDark,
      );

      final onCream = Color.alphaBlend(AppTheme.gridDotLight, cream);
      final onSoil = Color.alphaBlend(AppTheme.gridDotDark, soil);
      expect(
        AppTheme.getContrastRatio(onCream, cream),
        greaterThan(2.5),
      );
      expect(AppTheme.getContrastRatio(onSoil, soil), greaterThan(1.3));
      expect(onCream.computeLuminance(), lessThan(cream.computeLuminance()));
      expect(onSoil.computeLuminance(), greaterThan(soil.computeLuminance()));
    });

    test('the game stores the theme dot and the grid applies it once', () {
      final game = GardenGame(sink: TestGameEventSink());
      expect(game.gridDotColor, AppTheme.gridDotDark);

      game.updateThemeColors(
        cream,
        const Color(0xFFFFFBF3),
        const Color(0xFFF1EBDD),
        gridDotColor: AppTheme.gridDotLight,
      );
      expect(game.gridDotColor, AppTheme.gridDotLight);

      CellComponent.applyDotColor(game.gridDotColor);
      expect(CellComponent.dotColor, AppTheme.gridDotLight);

      CellComponent.applyDotColor(AppTheme.gridDotDark);
      expect(CellComponent.dotColor, AppTheme.gridDotDark);
    });
  });

  group('grid dot throb', () {
    test('scale rises to twice the resting size and settles', () {
      expect(GridDotPulse.scaleAt(-0.1), 1);
      expect(GridDotPulse.scaleAt(0), 1);
      expect(
        GridDotPulse.scaleAt(GridDotPulse.duration / 2),
        closeTo(1 + GridDotPulse.amplitude, 1e-9),
      );
      expect(GridDotPulse.amplitude, 1);
      expect(
          GridDotPulse.scaleAt(GridDotPulse.duration * 0.25), greaterThan(1));
      expect(
        GridDotPulse.scaleAt(GridDotPulse.duration * 0.25),
        lessThan(1 + GridDotPulse.amplitude),
      );
      expect(GridDotPulse.scaleAt(GridDotPulse.duration), 1);
      expect(GridDotPulse.scaleAt(GridDotPulse.duration + 0.2), 1);
    });

    test('a cell throbs once', () {
      final cell = CellComponent(
        gridX: 0,
        gridY: 0,
        size: Vector2.all(GameBoardLayout.cellSize),
        position: Vector2.zero(),
      );
      expect(cell.dotScale, 1);

      cell.pulse();
      cell.pulse();
      cell.update(GridDotPulse.duration / 2);
      expect(cell.dotScale, closeTo(1 + GridDotPulse.amplitude, 1e-6));

      cell.update(GridDotPulse.duration);
      expect(cell.dotScale, 1);

      cell.pulse();
      cell.update(GridDotPulse.duration / 2);
      expect(cell.dotScale, 1);
    });
  });

  group('clearing tail uncover', () {
    VineTrack straight() => VineTrack.build(
          orderedPath: const [
            {'x': 2, 'y': 0},
            {'x': 1, 'y': 0},
            {'x': 0, 'y': 0},
          ],
          headDirection: 'right',
          gridWidth: 4,
          gridHeight: 4,
          extensionArc: 0,
        );

    test('path cells run tail to head with the head at arc 0', () {
      final track = straight();
      final cells = track.pathCells;
      expect(cells.map((cell) => (cell.x, cell.y)), [
        (0, 0),
        (1, 0),
        (2, 0),
        (3, 0),
      ]);
      expect(cells.first.arc, closeTo(-track.windowLength, 0.5));
      expect(cells[2].arc, closeTo(0, 0.5));
      const pitch = GameBoardLayout.pointSpacing;
      expect(cells[1].arc - cells[0].arc, closeTo(pitch, 0.5));
      expect(cells[2].arc - cells[1].arc, closeTo(pitch, 0.5));
      expect(cells[3].arc, closeTo(pitch, 0.5));
    });

    test('an L path keeps cell arcs in tail-to-head order', () {
      final track = VineTrack.build(
        orderedPath: const [
          {'x': 2, 'y': 0},
          {'x': 1, 'y': 0},
          {'x': 0, 'y': 0},
          {'x': 0, 'y': 1},
        ],
        headDirection: 'right',
        gridWidth: 4,
        gridHeight: 4,
        extensionArc: GameBoardLayout.pointSpacing * 4,
      );
      final cells = track.pathCells;
      expect(cells.map((cell) => (cell.x, cell.y)), [
        (0, 1),
        (0, 0),
        (1, 0),
        (2, 0),
        (3, 0),
      ]);
      for (var i = 1; i < cells.length; i++) {
        expect(cells[i].arc, greaterThan(cells[i - 1].arc));
      }
      expect(cells.first.arc, closeTo(-track.windowLength, 1));
      expect(cells[3].arc, closeTo(0, 1));
      expect(
        cells.last.arc,
        closeTo(GameBoardLayout.pointSpacing.toDouble(), 1),
      );
    });

    test('a clear reports each passed cell once, and a block reports none', () {
      final cells = straight().pathCells;
      final reveal = VineDotReveal();
      final margin = VineTrack.dotUncoverMargin;
      final restingTail = cells.first.arc;

      expect(
        reveal.takeNewlyUncovered(cells, restingTail, clearing: true),
        isEmpty,
      );
      expect(
        reveal.takeNewlyUncovered(
          cells,
          cells.first.arc + margin,
          clearing: true,
        ),
        isEmpty,
      );

      final first = reveal.takeNewlyUncovered(
        cells,
        cells.first.arc + margin + 0.01,
        clearing: true,
      );
      expect(first.map((cell) => cell.x), [0]);
      expect(reveal.revealedCount, 1);

      expect(
        reveal.takeNewlyUncovered(cells, 10000, clearing: false),
        isEmpty,
      );
      expect(reveal.revealedCount, 1);

      final rest = reveal.takeNewlyUncovered(
        cells,
        10000,
        clearing: true,
      );
      expect(rest.map((cell) => cell.x), [1, 2, 3]);
      expect(
        reveal.takeNewlyUncovered(cells, 10000, clearing: true),
        isEmpty,
      );

      reveal.reset();
      expect(
        reveal.takeNewlyUncovered(cells, 10000, clearing: true).length,
        cells.length,
      );
    });

    test('a short vine throbs the whole column the tail climbs', () {
      final track = VineTrack.build(
        orderedPath: const [
          {'x': 1, 'y': 1},
          {'x': 1, 'y': 0},
        ],
        headDirection: 'up',
        gridWidth: 3,
        gridHeight: 6,
        extensionArc: 0,
      );
      final cells = track.pathCells;
      expect(cells.map((cell) => (cell.x, cell.y)), [
        (1, 0),
        (1, 1),
        (1, 2),
        (1, 3),
        (1, 4),
        (1, 5),
      ]);
      const pitch = GameBoardLayout.pointSpacing;
      expect(cells[1].arc, closeTo(0, 0.5));
      expect(cells[2].arc, closeTo(pitch, 0.5));
      expect(cells.last.arc, closeTo(4 * pitch, 0.5));

      final reveal = VineDotReveal();
      final margin = VineTrack.dotUncoverMargin;
      final passedBody = reveal.takeNewlyUncovered(
        cells,
        margin + 0.01,
        clearing: true,
      );
      expect(passedBody.map((cell) => cell.y), [0, 1]);

      final next = reveal.takeNewlyUncovered(
        cells,
        pitch + margin + 0.01,
        clearing: true,
      );
      expect(next.map((cell) => cell.y), [2]);
    });
  });

  group('masked cells', () {
    test('a hidden cell does not throb', () async {
      final game = _DotGame();
      await game.onLoad();
      final grid = game.grid;
      await grid.onLoad();
      grid.setLevelData(_maskedLevel(), const {});

      grid.pulseCell(0, 0);
      grid.cells[0][0].update(GridDotPulse.duration / 2);
      expect(grid.cells[0][0].dotScale, 1);

      grid.pulseCell(1, 0);
      grid.cells[0][1].update(GridDotPulse.duration / 2);
      expect(
        grid.cells[0][1].dotScale,
        closeTo(1 + GridDotPulse.amplitude, 1e-6),
      );
    });
  });
}

class _DotGame extends GardenGame {
  _DotGame() : super(sink: TestGameEventSink());

  @override
  Vector2 get size => Vector2(800, 600);
}

LevelData _maskedLevel() => LevelData(
      id: 'dots',
      name: 'Dots',
      difficulty: 'Seed',
      gridWidth: 2,
      gridHeight: 2,
      vines: const [],
      maxMoves: 1,
      minMoves: 1,
      complexity: 'low',
      grace: 1,
      mask: MaskData(
        mode: 'hide',
        points: const [
          {'x': 0, 'y': 0},
        ],
      ),
    );
