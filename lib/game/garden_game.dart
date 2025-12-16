// lib/game/garden_game.dart
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'components/grid_component.dart';

class GardenGame extends FlameGame {
  static const int gridSize = 6; // 6x6 for Week 1
  static const double cellSize = 80.0; // Pixels per cell

  late GridComponent grid;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // TODO: Replace with actual parable background image
    // Load parable background (placeholder for now)
    add(RectangleComponent(
      size: size,
      paint: Paint()..color = const Color(0xFFFFF8DC), // Cream background
      priority: -2,
    ));

    // TODO: Replace with actual grid background texture
    // Add grid background texture (placeholder)
    add(RectangleComponent(
      size: Vector2(gridSize * cellSize + 20, gridSize * cellSize + 20),
      position: Vector2(
        (size.x - (gridSize * cellSize + 20)) / 2,
        (size.y - (gridSize * cellSize + 20)) / 2,
      ),
      paint: Paint()..color = const Color(0xFFF5F5DC), // Beige grid background
      priority: -1,
    ));

    // Add the interactive grid
    grid = GridComponent(gridSize: gridSize, cellSize: cellSize);
    add(grid);

    // Center camera
    camera.viewport.size = size;
  }

  @override
  Color backgroundColor() => const Color(0xFF1E3528); // Dark forest base
}
