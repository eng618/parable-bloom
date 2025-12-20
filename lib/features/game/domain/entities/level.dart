import 'game_board.dart';
import 'vine.dart';
import 'grid_position.dart';

class Parable {
  final String title;
  final String scripture;
  final String content;
  final String reflection;
  final String backgroundImage;

  const Parable({
    required this.title,
    required this.scripture,
    required this.content,
    required this.reflection,
    required this.backgroundImage,
  });

  Parable copyWith({
    String? title,
    String? scripture,
    String? content,
    String? reflection,
    String? backgroundImage,
  }) {
    return Parable(
      title: title ?? this.title,
      scripture: scripture ?? this.scripture,
      content: content ?? this.content,
      reflection: reflection ?? this.reflection,
      backgroundImage: backgroundImage ?? this.backgroundImage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Parable &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          scripture == other.scripture;

  @override
  int get hashCode => title.hashCode ^ scripture.hashCode;

  @override
  String toString() => 'Parable(title: $title, scripture: $scripture)';
}

class Level {
  final String levelId;
  final int levelNumber;
  final String title;
  final int difficulty;
  final GameBoard gameBoard;
  final Parable parable;
  final List<String> hints;
  final List<String> optimalSequence;
  final int optimalMoves;

  const Level({
    required this.levelId,
    required this.levelNumber,
    required this.title,
    required this.difficulty,
    required this.gameBoard,
    required this.parable,
    required this.hints,
    required this.optimalSequence,
    required this.optimalMoves,
  });

  bool get isComplete => gameBoard.isComplete();

  List<String> get tappableVineIds =>
      gameBoard.getTappableVines().map((v) => v.id).toList();

  Level clearVine(String vineId) {
    return copyWith(gameBoard: gameBoard.clearVine(vineId));
  }

  Vine? getVineById(String id) => gameBoard.getVineById(id);

  Vine? getVineAtCell(GridPosition pos) => gameBoard.getVineAtCell(pos);

  Level copyWith({
    String? levelId,
    int? levelNumber,
    String? title,
    int? difficulty,
    GameBoard? gameBoard,
    Parable? parable,
    List<String>? hints,
    List<String>? optimalSequence,
    int? optimalMoves,
  }) {
    return Level(
      levelId: levelId ?? this.levelId,
      levelNumber: levelNumber ?? this.levelNumber,
      title: title ?? this.title,
      difficulty: difficulty ?? this.difficulty,
      gameBoard: gameBoard ?? this.gameBoard,
      parable: parable ?? this.parable,
      hints: hints ?? this.hints,
      optimalSequence: optimalSequence ?? this.optimalSequence,
      optimalMoves: optimalMoves ?? this.optimalMoves,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Level &&
          runtimeType == other.runtimeType &&
          levelId == other.levelId;

  @override
  int get hashCode => levelId.hashCode;

  @override
  String toString() =>
      'Level(levelId: $levelId, number: $levelNumber, title: $title, complete: $isComplete)';
}
