import '../../domain/entities/level.dart';
import '../../domain/entities/game_board.dart';
import 'vine_model.dart';

class LevelModel {
  final String levelId;
  final int levelNumber;
  final String title;
  final int difficulty;
  final int rows;
  final int cols;
  final List<VineModel> vines;
  final String parableTitle;
  final String scripture;
  final String content;
  final String reflection;
  final String backgroundImage;
  final List<String> hints;
  final List<String> optimalSequence;
  final int optimalMoves;

  LevelModel({
    required this.levelId,
    required this.levelNumber,
    required this.title,
    required this.difficulty,
    required this.rows,
    required this.cols,
    required this.vines,
    required this.parableTitle,
    required this.scripture,
    required this.content,
    required this.reflection,
    required this.backgroundImage,
    required this.hints,
    required this.optimalSequence,
    required this.optimalMoves,
  });

  factory LevelModel.fromJson(Map<String, dynamic> json) {
    return LevelModel(
      levelId: json['levelId'],
      levelNumber: json['levelNumber'],
      title: json['title'],
      difficulty: json['difficulty'],
      rows: json['grid']['rows'],
      cols: json['grid']['columns'],
      vines: (json['vines'] as List).map((v) => VineModel.fromJson(v)).toList(),
      parableTitle: json['parable']['title'],
      scripture: json['parable']['scripture'],
      content: json['parable']['content'],
      reflection: json['parable']['reflection'],
      backgroundImage: json['parable']['backgroundImage'],
      hints: List<String>.from(json['hints'] ?? []),
      optimalSequence: List<String>.from(json['optimalSequence'] ?? []),
      optimalMoves: json['optimalMoves'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'levelId': levelId,
      'levelNumber': levelNumber,
      'title': title,
      'difficulty': difficulty,
      'grid': {'rows': rows, 'columns': cols},
      'vines': vines.map((v) => v.toJson()).toList(),
      'parable': {
        'title': parableTitle,
        'scripture': scripture,
        'content': content,
        'reflection': reflection,
        'backgroundImage': backgroundImage,
      },
      'hints': hints,
      'optimalSequence': optimalSequence,
      'optimalMoves': optimalMoves,
    };
  }

  Level toDomain() {
    final gameBoard = GameBoard(
      rows: rows,
      cols: cols,
      vines: vines.map((v) => v.toDomain()).toList(),
    );

    final parable = Parable(
      title: parableTitle,
      scripture: scripture,
      content: content,
      reflection: reflection,
      backgroundImage: backgroundImage,
    );

    return Level(
      levelId: levelId,
      levelNumber: levelNumber,
      title: title,
      difficulty: difficulty,
      gameBoard: gameBoard,
      parable: parable,
      hints: hints,
      optimalSequence: optimalSequence,
      optimalMoves: optimalMoves,
    );
  }
}
