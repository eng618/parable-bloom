import "game_progress.dart";

enum CloudSyncAvailabilityReason {
  available,
  signedOut,
  anonymousAccount,
}

class CloudSyncAvailability {
  final bool isAvailable;
  final CloudSyncAvailabilityReason reason;

  const CloudSyncAvailability({
    required this.isAvailable,
    required this.reason,
  });
}

enum SyncConflictType {
  none,
  localAhead,
  cloudAhead,
  divergent,
}

enum SyncConflictResolution {
  keepLocal,
  keepCloud,
}

class SyncConflictState {
  final SyncConflictType type;
  final GameProgress localProgress;
  final GameProgress? cloudProgress;

  const SyncConflictState({
    required this.type,
    required this.localProgress,
    required this.cloudProgress,
  });

  bool get requiresUserDecision =>
      type == SyncConflictType.localAhead || type == SyncConflictType.divergent;

  bool get cloudHasData => cloudProgress != null;
}
