import 'package:flutter_riverpod/flutter_riverpod.dart';

final levelTotalTapsProvider = NotifierProvider<LevelTotalTapsNotifier, int>(
  LevelTotalTapsNotifier.new,
);

class LevelTotalTapsNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void increment() {
    state++;
  }

  void reset() {
    state = 0;
  }
}

final levelWrongTapsProvider = NotifierProvider<LevelWrongTapsNotifier, int>(
  LevelWrongTapsNotifier.new,
);

class LevelWrongTapsNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void increment() {
    state++;
  }

  void reset() {
    state = 0;
  }
}

final levelAttemptCountProvider =
    NotifierProvider<LevelAttemptCountNotifier, int>(
  LevelAttemptCountNotifier.new,
);

class LevelAttemptCountNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void set(int count) {
    state = count;
  }

  void increment() {
    state++;
  }

  void reset() {
    state = 0;
  }
}

final levelStartTimestampProvider =
    NotifierProvider<LevelStartTimestampNotifier, int?>(
  LevelStartTimestampNotifier.new,
);

class LevelStartTimestampNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void set(DateTime dateTime) {
    state = dateTime.millisecondsSinceEpoch;
  }

  void reset() {
    state = null;
  }
}
