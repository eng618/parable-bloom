// lib/main.dart
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'game/garden_game.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive (local storage)
  await Hive.initFlutter();
  await Hive.openBox('garden_save'); // We'll use this for progress

  runApp(const ParableWeaveApp());
}

class ParableWeaveApp extends StatelessWidget {
  const ParableWeaveApp({super.key});

  @override
  Widget build(BuildContext context) {
    final game = GardenGame();

    return MaterialApp(
      title: 'ParableWeave',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF2D4A3A), // Deep moss green - matches game design
        appBar: AppBar(
          title: const Text('ParableWeave'),
          backgroundColor: const Color(0xFF1E3528),
          actions: [
            // TODO: Replace with actual UI buttons
            // Placeholder hint button - replace with actual hint system
            IconButton(
              icon: const Icon(Icons.lightbulb),
              onPressed: () {
                // Placeholder hint action
                debugPrint('Hint button pressed - replace with actual hint system');
              },
              tooltip: 'Hint (placeholder)',
            ),
            // TODO: Replace with settings menu
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                // Placeholder settings action
                debugPrint('Settings button pressed - replace with actual settings');
              },
              tooltip: 'Settings (placeholder)',
            ),
          ],
        ),
        body: Stack(
          children: [
            GameWidget<GardenGame>(
              game: game,
              loadingBuilder: (_) => const Center(
                child: CircularProgressIndicator(color: Colors.white70),
              ),
            ),
            // TODO: Replace with actual parable reveal overlay
            // Placeholder parable text overlay - replace with actual parable system
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Placeholder Parable Text',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      '"I am the true vine, and my Father is the gardener..." - John 15:1',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
