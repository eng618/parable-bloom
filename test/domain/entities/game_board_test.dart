import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/features/game/domain/entities/game_board.dart';
import 'package:parable_bloom/features/game/domain/entities/grid_position.dart';
import 'package:parable_bloom/features/game/domain/entities/vine.dart';

void main() {
  group('GameBoard Entity', () {
    late GameBoard gameBoard;
    late Vine vine1;
    late Vine vine2;
    late Vine blockingVine;

    setUp(() {
      vine1 = Vine(
        id: 'vine1',
        path: [GridPosition(0, 0), GridPosition(0, 1), GridPosition(0, 2)],
        color: '#FF0000',
        blockingVines: ['blocking_vine'],
        description: 'Vine 1',
      );

      vine2 = Vine(
        id: 'vine2',
        path: [GridPosition(1, 0), GridPosition(1, 1), GridPosition(1, 2)],
        color: '#00FF00',
        blockingVines: [],
        description: 'Vine 2',
      );

      blockingVine = Vine(
        id: 'blocking_vine',
        path: [GridPosition(2, 0), GridPosition(2, 1), GridPosition(2, 2)],
        color: '#0000FF',
        blockingVines: [],
        description: 'Blocking Vine',
      );

      gameBoard = GameBoard(
        rows: 3,
        cols: 3,
        vines: [vine1, vine2, blockingVine],
      );
    });

    test('should return tappable vines correctly', () {
      final tappableVines = gameBoard.getTappableVines();

      // vine1 is blocked by blockingVine, vine2 has no blockers, blockingVine has no blockers
      expect(tappableVines.length, 2);
      expect(tappableVines.map((v) => v.id), contains('vine2'));
      expect(tappableVines.map((v) => v.id), contains('blocking_vine'));
      expect(tappableVines.map((v) => v.id), isNot(contains('vine1')));
    });

    test('should create correct cell occupancy map', () {
      final occupancy = gameBoard.getCellOccupancy();

      expect(occupancy.length, 9); // 3x3 grid, all cells occupied
      expect(occupancy[GridPosition(0, 0)], 'vine1');
      expect(occupancy[GridPosition(1, 1)], 'vine2');
      expect(occupancy[GridPosition(2, 2)], 'blocking_vine');
    });

    test('should clear vine correctly', () {
      final newBoard = gameBoard.clearVine('vine2');

      expect(newBoard.vines.length, 2);
      expect(newBoard.vines.map((v) => v.id), contains('vine1'));
      expect(newBoard.vines.map((v) => v.id), contains('blocking_vine'));
      expect(newBoard.vines.map((v) => v.id), isNot(contains('vine2')));
    });

    test('should return correct vine by id', () {
      expect(gameBoard.getVineById('vine1'), equals(vine1));
      expect(gameBoard.getVineById('nonexistent'), isNull);
    });

    test('should return correct vine at cell position', () {
      expect(gameBoard.getVineAtCell(GridPosition(0, 1)), equals(vine1));
      expect(gameBoard.getVineAtCell(GridPosition(1, 1)), equals(vine2));
      expect(gameBoard.getVineAtCell(GridPosition(5, 5)), isNull);
    });

    test('should detect when board is complete', () {
      expect(gameBoard.isComplete(), isFalse);

      final emptyBoard = GameBoard(rows: 3, cols: 3, vines: []);
      expect(emptyBoard.isComplete(), isTrue);
    });

    test('should throw exception for overlapping cells', () {
      final overlappingVine = Vine(
        id: 'overlap',
        path: [GridPosition(0, 0)], // Same position as vine1
        color: '#FFFF00',
        blockingVines: [],
        description: 'Overlapping vine',
      );

      final overlappingBoard = GameBoard(
        rows: 3,
        cols: 3,
        vines: [vine1, overlappingVine],
      );

      expect(() => overlappingBoard.getCellOccupancy(), throwsException);
    });

    test('copyWith should create new instance with updated values', () {
      final newBoard = gameBoard.copyWith(rows: 5, cols: 5);

      expect(newBoard.rows, 5);
      expect(newBoard.cols, 5);
      expect(newBoard.vines, gameBoard.vines);
    });
  });
}
