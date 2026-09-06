import '../../application/providers/gameplay_state_providers.dart'
    show VineAnimationState;
import '../../domain/entities/level_data.dart' show VineData;
import '../../../tutorial/presentation/widgets/tutorial_guide_overlay.dart'
    show BlockedTapState;
import 'garden_game.dart';

/// Single bridge between the Flame engine ([GardenGame] and its components)
/// and the Flutter/Riverpod layer.
///
/// Replaces the previous 15-closure `GardenGameCallbacks` struct: one named
/// interface is easier to implement, mock, and extend than a bag of
/// closures that every construction site had to fill in.
abstract class GameEventSink {
  void onGameLoaded(GardenGame game);
  void onGameRemoved();
  void onVineCleared(String vineId);
  void onVineAnimationStateChanged(String vineId, VineAnimationState state);
  void onVineAttempted(String vineId);
  void onTapIncrement(int count);
  void onTapOutsideGrid();
  void onBlockedTap(BlockedTapState state);
  Future<void> onEnsureVineVisible(VineData vine);
  void onHintVine(String vineId);
  void onClearHints();

  bool get useSimpleVines;
  bool get hapticsEnabled;
  bool get isAnyAnimating;
  bool get debugShowGridCoordinates;
  bool get debugVineAnimationLogging;
}

/// No-op [GameEventSink] for tests that need a game instance without
/// Flutter-layer behavior.
class TestGameEventSink implements GameEventSink {
  @override
  void onGameLoaded(GardenGame game) {}

  @override
  void onGameRemoved() {}

  @override
  void onVineCleared(String vineId) {}

  @override
  void onVineAnimationStateChanged(String vineId, VineAnimationState state) {}

  @override
  void onVineAttempted(String vineId) {}

  @override
  void onTapIncrement(int count) {}

  @override
  void onTapOutsideGrid() {}

  @override
  void onBlockedTap(BlockedTapState state) {}

  @override
  Future<void> onEnsureVineVisible(VineData vine) async {}

  @override
  void onHintVine(String vineId) {}

  @override
  void onClearHints() {}

  @override
  bool get useSimpleVines => false;

  @override
  bool get hapticsEnabled => false;

  @override
  bool get isAnyAnimating => false;

  @override
  bool get debugShowGridCoordinates => false;

  @override
  bool get debugVineAnimationLogging => false;
}
