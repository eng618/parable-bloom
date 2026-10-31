part of 'game_screen.dart';

/// [GameEventSink] bridging the Flame engine to [_GameScreenState].
///
/// Holds the state (same library, so private members are accessible) instead
/// of a bag of closures: one named implementation per screen, mockable in
/// tests via [TestGameEventSink].
class _GameScreenEventSink implements GameEventSink {
  _GameScreenEventSink(this._state);

  final _GameScreenState _state;

  ProviderContainer? get _container => _state._providerContainer;

  /// Element-tree-independent provider read (see [_GameScreenState._providerContainer]).
  /// Falls back to [fallback] when the screen was never attached or the app
  /// is tearing down. Safe to call from the Flame game loop at any time.
  T _read<T>(T Function(ProviderContainer container) read, T fallback) {
    final container = _container;
    if (container == null) return fallback;
    try {
      return read(container);
    } on StateError {
      return fallback;
    }
  }

  /// Fire-and-forget provider mutation with the same lifecycle safety as
  /// [_read]. Mutating a live container after unmount is harmless (listeners
  /// are already closed), and game truth must not depend on widget presence.
  void _call(void Function(ProviderContainer container) fn) {
    final container = _container;
    if (container == null) return;
    try {
      fn(container);
    } on StateError {
      // App teardown: container disposed; nothing left to update.
    }
  }

  @override
  void onGameLoaded(GardenGame game) {
    if (!_state.mounted) return;
    _call((c) => c.read(gameInstanceProvider.notifier).setGame(game));
    _state._loadLevelForGame(game);
  }

  @override
  void onGameRemoved() {
    if (!_state.mounted) return;
    _call((c) {
      if (c.read(gameInstanceProvider) == _state._game) {
        c.read(gameInstanceProvider.notifier).setGame(null);
      }
    });
  }

  @override
  void onVineCleared(String vineId) {
    _call((c) => c.read(vineStatesProvider.notifier).clearVine(vineId));
  }

  @override
  void onVineAnimationStateChanged(String vineId, VineAnimationState state) {
    _call((c) =>
        c.read(vineStatesProvider.notifier).setAnimationState(vineId, state));
  }

  @override
  void onVineAttempted(String vineId) {
    _call((c) => c.read(vineStatesProvider.notifier).markAttempted(vineId));
  }

  @override
  void onTapIncrement(int count) {
    _call((c) => c.read(levelTotalTapsProvider.notifier).add(count));
  }

  @override
  void onTapOutsideGrid() {
    _call((c) => c.read(projectionModeProvider.notifier).clearHints());
  }

  @override
  void onBlockedTap(BlockedTapState state) {
    _call((c) => c.read(blockedTapProvider.notifier).setBlockedTap(state));
  }

  @override
  Future<void> onEnsureVineVisible(VineData vine) async {
    final container = _container;
    if (container == null) return;
    try {
      await container
          .read(cameraStateProvider.notifier)
          .ensureVineVisible(vine);
    } on StateError {
      // App teardown mid-flight; the pending auto-clear is obsolete.
    }
  }

  @override
  void onHintVine(String vineId) {
    _call((c) => c.read(projectionModeProvider.notifier).hint(vineId));
  }

  @override
  void onClearHints() {
    _call((c) => c.read(projectionModeProvider.notifier).clearHints());
  }

  @override
  void onVineSlideStarted({required int vineLength}) {
    _call(dispatchVineSlideStarted);
  }

  @override
  void onVineSlideEnded({required bool cleared, required int vineLength}) {
    _call(
      (c) => dispatchVineSlideEnded(
        c,
        cleared: cleared,
        vineLength: vineLength,
      ),
    );
  }

  @override
  void onUiTap() {
    _call(dispatchUiTap);
  }

  @override
  bool get useSimpleVines =>
      _read((c) => c.read(useSimpleVinesProvider), false);

  @override
  bool get hapticsEnabled =>
      _read((c) => c.read(hapticsEnabledProvider), false);

  @override
  bool get isAnyAnimating =>
      _read((c) => c.read(anyVineAnimatingProvider), false);

  @override
  bool get debugShowGridCoordinates =>
      _read((c) => c.read(debugShowGridCoordinatesProvider), false);

  @override
  bool get debugVineAnimationLogging =>
      _read((c) => c.read(debugVineAnimationLoggingProvider), false);

  @override
  VineStyle get vineStyle =>
      _read((c) => c.read(vineStyleProvider), VineStyle.classic);
}
