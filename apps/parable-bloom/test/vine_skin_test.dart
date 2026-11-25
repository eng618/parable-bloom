import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:parable_bloom/core/game_board_layout.dart';
import 'package:parable_bloom/core/providers/settings_providers.dart'
    show VineStyle;
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_end_sprites.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_metrics.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_skin.dart';
import 'package:parable_bloom/features/game/presentation/widgets/vine/vine_track.dart';

void main() {
  test('Classic is the only modular style in this template pass', () {
    expect(VineSkinTheme.usesModularLayers(VineStyle.classic), isTrue);
    expect(VineSkinTheme.usesModularLayers(VineStyle.blossom), isFalse);
    expect(VineSkinTheme.usesModularLayers(VineStyle.ethereal), isFalse);
    expect(VineSkinTheme.usesModularLayers(VineStyle.simple), isFalse);
  });

  test('theme wrap/head/tail tiles flip with withered state', () async {
    final shaft = await _solidImage(4, 8);
    final wrapLive = await _solidImage(4, 8);
    final wrapWithered = await _solidImage(4, 8);
    final ends = await _solidImage(16, 4); // 4 tiles × 4px
    addTearDown(() {
      shaft.dispose();
      wrapLive.dispose();
      wrapWithered.dispose();
      ends.dispose();
    });

    final theme = VineSkinTheme(
      id: 'classic',
      shaft: shaft,
      wrapLive: wrapLive,
      wrapWithered: wrapWithered,
      endsAtlas: ends,
      tileSize: 4,
    );

    expect(identical(theme.wrapFor(VineSkinState.live), wrapLive), isTrue);
    expect(
      identical(theme.wrapFor(VineSkinState.withered), wrapWithered),
      isTrue,
    );
    expect(theme.headTile(VineSkinState.live), 0);
    expect(theme.headTile(VineSkinState.withered), 1);
    expect(theme.tailTile(VineSkinState.live), 2);
    expect(theme.tailTile(VineSkinState.withered), 3);
  });

  test('end sprites build oriented quads at head and tail arcs', () async {
    final shaft = await _solidImage(8, 16);
    final wrap = await _solidImage(8, 16);
    final ends = await _solidImage(32, 8);
    addTearDown(() {
      shaft.dispose();
      wrap.dispose();
      ends.dispose();
    });

    final theme = VineSkinTheme(
      id: 'classic',
      shaft: shaft,
      wrapLive: wrap,
      wrapWithered: wrap,
      endsAtlas: ends,
      tileSize: 8,
    );

    const pitch = GameBoardLayout.pointSpacing;
    final track = VineTrack.build(
      orderedPath: const [
        {'x': 2, 'y': 0},
        {'x': 1, 'y': 0},
        {'x': 0, 'y': 0},
      ],
      headDirection: 'right',
      gridWidth: 4,
      gridHeight: 2,
      extensionArc: 4 * pitch,
    );

    final head = VineEndSprites.quad(
      theme: theme,
      track: track,
      arc: 0,
      tile: theme.headTile(VineSkinState.live),
      tint: const Color(0xFFFFFFFF),
      halfSize: VineEndSprites.halfSizeForTube(),
      flipForTail: false,
    );
    final tail = VineEndSprites.quad(
      theme: theme,
      track: track,
      arc: -track.windowLength,
      tile: theme.tailTile(VineSkinState.live),
      tint: const Color(0xFFFFFFFF),
      halfSize: VineEndSprites.halfSizeForTube(),
      flipForTail: true,
    );

    expect(head, isNotNull);
    expect(tail, isNotNull);
    expect(VineMetrics.skinEndScale, greaterThan(1.0));
  });
}

Future<ui.Image> _solidImage(int w, int h) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final paint = ui.Paint()..color = const Color(0xFFFFFFFF);
  canvas.drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), paint);
  final picture = recorder.endRecording();
  return picture.toImage(w, h);
}
