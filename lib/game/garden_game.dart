import 'dart:convert';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../providers/game_providers.dart';
import 'components/grid_component.dart';

class GardenGame extends FlameGame {
  static const double cellSize = 80.0; // Pixels per cell

  late GridComponent grid;
  late ProviderContainer _container;
  LevelData? _currentLevelData;

  GardenGame({required Box<dynamic> hiveBox}) {
    _container = ProviderContainer(overrides: [
      hiveBoxProvider.overrideWithValue(hiveBox),
    ]);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Load current level first
    await _loadCurrentLevel();

    // TODO: Replace with actual parable background image
    // Load parable background (placeholder for now)
    add(RectangleComponent(
      size: size,
      paint: Paint()..color = const Color(0xFFFFF8DC), // Cream background
      priority: -2,
    ));

    // TODO: Replace with actual grid background texture
    // Add grid background texture (placeholder)
    final gridSize = _currentLevelData!.grid['rows'] as int;
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
    grid = GridComponent(
      gridSize: gridSize,
      cellSize: cellSize,
      onVineCleared: (vineId) {
        // Update the Riverpod provider when a vine is cleared
        _container.read(vineStatesProvider.notifier).clearVine(vineId);
      },
    );
    add(grid);

    // Set level data on grid after it's created
    if (_currentLevelData != null) {
      await _setLevelDataOnGrid();
    }

    // Center camera
    camera.viewport.size = size;
  }

  Future<void> _loadCurrentLevel() async {
    final progress = _container.read(gameProgressProvider);
    final levelNumber = progress.currentLevel;

    try {
      // Load level data from JSON
      final levelJson = await rootBundle.loadString('assets/levels/level_$levelNumber.json');
      _currentLevelData = LevelData.fromJson(json.decode(levelJson));

      // Update providers
      _container.read(currentLevelProvider.notifier).state = _currentLevelData;

      debugPrint('Loaded level $levelNumber: ${_currentLevelData!.title}');
    } catch (e) {
      debugPrint('Error loading level $levelNumber: $e');
    }
  }

  Future<void> _setLevelDataOnGrid() async {
    if (_currentLevelData == null) return;

    // Initialize vine states based on blocking rules
    final vineStates = <String, VineState>{};
    for (final vine in _currentLevelData!.vines) {
      vineStates[vine.id] = VineState(
        id: vine.id,
        isBlocked: vine.blockingVines.isNotEmpty,
        isCleared: false,
      );
    }

    // Set data on grid
    grid.setLevelData(_currentLevelData!, vineStates);
  }

  @override
  Color backgroundColor() => const Color(0xFF1E3528); // Dark forest base

  @override
  void onRemove() {
    _container.dispose();
    super.onRemove();
  }

  // Method to reload the current level (called when progress is reset)
  Future<void> reloadLevel() async {
    await _loadCurrentLevel();
    if (_currentLevelData != null) {
      // Reset vine states for the new level
      _container.read(vineStatesProvider.notifier).resetForLevel(_currentLevelData!);
      await _setLevelDataOnGrid();
    }
  }
}
