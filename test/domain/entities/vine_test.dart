import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/features/game/domain/entities/grid_position.dart';
import 'package:parable_bloom/features/game/domain/entities/vine.dart';

void main() {
  group('Vine Entity', () {
    late Vine vine;
    late Vine blockingVine;

    setUp(() {
      vine = Vine(
        id: 'test_vine',
        path: [GridPosition(0, 0), GridPosition(0, 1), GridPosition(0, 2)],
        color: '#FF0000',
        blockingVines: ['blocking_vine'],
        description: 'Test vine',
      );

      blockingVine = Vine(
        id: 'blocking_vine',
        path: [GridPosition(1, 0), GridPosition(1, 1), GridPosition(1, 2)],
        color: '#00FF00',
        blockingVines: [],
        description: 'Blocking vine',
      );
    });

    test('should be blocked when blocking vine exists', () {
      final allVines = [vine, blockingVine];
      expect(vine.isBlocked(allVines), isTrue);
    });

    test('should not be blocked when no blocking vines exist', () {
      final allVines = [vine];
      expect(vine.isBlocked(allVines), isFalse);
    });

    test('should be tappable when not blocked', () {
      final allVines = [vine];
      expect(vine.isTappable(allVines), isTrue);
    });

    test('should not be tappable when blocked', () {
      final allVines = [vine, blockingVine];
      expect(vine.isTappable(allVines), isFalse);
    });

    test('copyWith should create new instance with updated values', () {
      final updatedVine = vine.copyWith(
        color: '#0000FF',
        description: 'Updated vine',
      );

      expect(updatedVine.id, vine.id);
      expect(updatedVine.color, '#0000FF');
      expect(updatedVine.description, 'Updated vine');
      expect(updatedVine.path, vine.path);
    });

    test('should be equal when all properties are the same', () {
      final anotherVine = Vine(
        id: 'test_vine',
        path: [GridPosition(0, 0), GridPosition(0, 1), GridPosition(0, 2)],
        color: '#FF0000',
        blockingVines: ['blocking_vine'],
        description: 'Test vine',
      );

      expect(vine, equals(anotherVine));
    });

    test('should not be equal when id is different', () {
      final differentVine = vine.copyWith(id: 'different_id');
      expect(vine, isNot(equals(differentVine)));
    });
  });
}
