import '../../domain/entities/vine.dart';
import '../../domain/entities/grid_position.dart';

class VineModel {
  final String id;
  final String color;
  final String description;
  final List<Map<String, int>> path;
  final List<String> blockingVines;

  VineModel({
    required this.id,
    required this.color,
    required this.description,
    required this.path,
    required this.blockingVines,
  });

  factory VineModel.fromJson(Map<String, dynamic> json) {
    return VineModel(
      id: json['id'],
      color: json['color'],
      description: json['description'],
      path: List<Map<String, int>>.from(
        json['path'].map((cell) => Map<String, int>.from(cell)),
      ),
      blockingVines: List<String>.from(json['blockingVines'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'color': color,
      'description': description,
      'path': path,
      'blockingVines': blockingVines,
    };
  }

  Vine toDomain() {
    return Vine(
      id: id,
      path: path
          .map((cell) => GridPosition(cell['row']!, cell['col']!))
          .toList(),
      color: color,
      blockingVines: blockingVines,
      description: description,
    );
  }

  factory VineModel.fromDomain(Vine vine) {
    return VineModel(
      id: vine.id,
      color: vine.color,
      description: vine.description,
      path: vine.path.map((pos) => {'row': pos.row, 'col': pos.col}).toList(),
      blockingVines: vine.blockingVines,
    );
  }
}
