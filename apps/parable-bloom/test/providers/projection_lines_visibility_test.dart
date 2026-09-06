import 'package:flutter_test/flutter_test.dart';
import 'package:parable_bloom/features/game/presentation/widgets/garden_game.dart';
import 'package:parable_bloom/features/game/presentation/widgets/projection_lines_component.dart';

void main() {
  group('ProjectionLinesComponent.updateVisibility contract', () {
    test('show-all marks every vine drawable', () {
      final component = ProjectionLinesComponent(cellSize: 48);
      component.updateVisibility(
        visible: true,
        hintedVineIds: const {},
        showAllVines: true,
      );

      expect(component.isProjectionVisible, isTrue);
      expect(component.showAllVines, isTrue);
      expect(component.hintedVineIds, isEmpty);
    });

    test('single hint exposes only the hinted vine', () {
      final component = ProjectionLinesComponent(cellSize: 48);
      component.updateVisibility(
        visible: true,
        hintedVineIds: const {'vine_1'},
        showAllVines: false,
      );

      expect(component.isProjectionVisible, isTrue);
      expect(component.showAllVines, isFalse);
      expect(component.hintedVineIds, contains('vine_1'));
    });

    test('hidden state draws nothing', () {
      final component = ProjectionLinesComponent(cellSize: 48);
      component.updateVisibility(
        visible: false,
        hintedVineIds: const {},
        showAllVines: false,
      );

      expect(component.isProjectionVisible, isFalse);
    });
  });

  group('GardenGame.resolveProjectionVisibility', () {
    test('FAB show-all forwards showAllVines=true', () {
      final resolved = GardenGame.resolveProjectionVisibility(
        visible: true,
        hintedVines: const {},
        isAnimating: false,
      );

      expect(resolved.visible, isTrue);
      expect(resolved.showAllVines, isTrue);
      expect(resolved.hintedVineIds, isEmpty);
    });

    test('long-press hint forwards the hinted id (regression)', () {
      final resolved = GardenGame.resolveProjectionVisibility(
        visible: false,
        hintedVines: const {'vine_1'},
        isAnimating: false,
      );

      // This is the exact case that was dropped by the old setVisible-only
      // bridge: visible was true but the id set never reached the component.
      expect(resolved.visible, isTrue);
      expect(resolved.showAllVines, isFalse);
      expect(resolved.hintedVineIds, contains('vine_1'));
    });

    test('animation hides both modes', () {
      final showAll = GardenGame.resolveProjectionVisibility(
        visible: true,
        hintedVines: const {},
        isAnimating: true,
      );
      final hint = GardenGame.resolveProjectionVisibility(
        visible: false,
        hintedVines: const {'vine_1'},
        isAnimating: true,
      );

      expect(showAll.visible, isFalse);
      expect(hint.visible, isFalse);
    });

    test('idle with no hints stays hidden', () {
      final resolved = GardenGame.resolveProjectionVisibility(
        visible: false,
        hintedVines: const {},
        isAnimating: false,
      );

      expect(resolved.visible, isFalse);
      expect(resolved.showAllVines, isFalse);
    });
  });
}
