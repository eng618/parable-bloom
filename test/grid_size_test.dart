import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/providers/game_providers.dart';

void main() {
  group('Grid Size and Cell Visibility Tests', () {
    test('LevelData should parse grid_size from JSON', () {
      final json = {
        'id': 1,
        'name': 'Test Level',
        'difficulty': 'Easy',
        'grid_size': {
          'rows': 7,
          'cols': 9,
        },
        'vines': [
          {
            'id': 'vine_a',
            'head_direction': 'right',
            'ordered_path': [
              {'x': 1, 'y': 1},
              {'x': 0, 'y': 1},
            ],
            'color': 'moss_green',
          }
        ],
        'max_moves': 5,
        'min_moves': 3,
        'complexity': 'easy',
        'grace': 3,
      };

      final level = LevelData.fromJson(json);

      expect(level.gridRows, equals(7));
      expect(level.gridCols, equals(9));
      expect(level.width, equals(9)); // Uses gridCols
      expect(level.height, equals(7)); // Uses gridRows
    });

    test('LevelData should fallback to calculated bounds when grid_size is missing', () {
      final json = {
        'id': 1,
        'name': 'Test Level',
        'difficulty': 'Easy',
        'vines': [
          {
            'id': 'vine_a',
            'head_direction': 'right',
            'ordered_path': [
              {'x': 4, 'y': 2},
              {'x': 3, 'y': 2},
              {'x': 2, 'y': 2},
              {'x': 1, 'y': 2},
              {'x': 0, 'y': 2},
            ],
            'color': 'moss_green',
          }
        ],
        'max_moves': 5,
        'min_moves': 3,
        'complexity': 'easy',
        'grace': 3,
      };

      final level = LevelData.fromJson(json);

      expect(level.gridRows, isNull);
      expect(level.gridCols, isNull);
      expect(level.width, equals(5)); // Calculated from bounds (0 to 4 = 5)
      expect(level.height, equals(1)); // Calculated from bounds (2 to 2 = 1)
    });

    test('getOccupiedPositions should return all vine positions', () {
      final json = {
        'id': 1,
        'name': 'Test Level',
        'difficulty': 'Easy',
        'grid_size': {
          'rows': 5,
          'cols': 5,
        },
        'vines': [
          {
            'id': 'vine_a',
            'head_direction': 'right',
            'ordered_path': [
              {'x': 2, 'y': 0},
              {'x': 1, 'y': 0},
              {'x': 0, 'y': 0},
            ],
            'color': 'moss_green',
          },
          {
            'id': 'vine_b',
            'head_direction': 'up',
            'ordered_path': [
              {'x': 4, 'y': 4},
              {'x': 4, 'y': 3},
              {'x': 4, 'y': 2},
            ],
            'color': 'sage',
          }
        ],
        'max_moves': 5,
        'min_moves': 3,
        'complexity': 'easy',
        'grace': 3,
      };

      final level = LevelData.fromJson(json);
      final occupied = level.getOccupiedPositions();

      expect(occupied, hasLength(6));
      expect(occupied, contains('0,0'));
      expect(occupied, contains('1,0'));
      expect(occupied, contains('2,0'));
      expect(occupied, contains('4,2'));
      expect(occupied, contains('4,3'));
      expect(occupied, contains('4,4'));
      
      // Test that unoccupied positions are not in the set
      expect(occupied, isNot(contains('3,3')));
      expect(occupied, isNot(contains('0,4')));
    });

    test('Grid size from JSON should allow for sparse grids', () {
      // This test ensures that we can have a large grid with only a few cells occupied
      final json = {
        'id': 1,
        'name': 'Sparse Grid Level',
        'difficulty': 'Medium',
        'grid_size': {
          'rows': 10,
          'cols': 10,
        },
        'vines': [
          {
            'id': 'vine_a',
            'head_direction': 'right',
            'ordered_path': [
              {'x': 1, 'y': 1},
              {'x': 0, 'y': 1},
            ],
            'color': 'moss_green',
          }
        ],
        'max_moves': 5,
        'min_moves': 1,
        'complexity': 'medium',
        'grace': 3,
      };

      final level = LevelData.fromJson(json);
      final occupied = level.getOccupiedPositions();

      expect(level.width, equals(10));
      expect(level.height, equals(10));
      expect(occupied, hasLength(2)); // Only 2 cells occupied in a 10x10 grid
      expect(occupied, contains('0,1'));
      expect(occupied, contains('1,1'));
    });
  });
}
