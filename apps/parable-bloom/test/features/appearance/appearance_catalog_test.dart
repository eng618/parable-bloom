import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:parable_bloom/core/providers/infrastructure_providers.dart';
import 'package:parable_bloom/features/appearance/application/appearance_providers.dart';
import 'package:parable_bloom/features/appearance/data/appearance_catalog.dart';
import 'package:parable_bloom/features/appearance/domain/appearance_pack.dart';
import 'package:parable_bloom/features/appearance/domain/appearance_slot.dart';
import 'package:parable_bloom/features/appearance/domain/vine_skin.dart';
import 'package:parable_bloom/features/appearance/presentation/widgets/themed_asset.dart';
import 'package:parable_bloom/features/game/presentation/widgets/level_complete_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppearanceWindow', () {
    const christmas = AppearanceWindow(
      fromMonth: 12,
      fromDay: 1,
      untilMonth: 1,
      untilDay: 6,
    );

    test('includes both ends and wraps the new year', () {
      expect(christmas.contains(DateTime(2026, 11, 30)), isFalse);
      expect(christmas.contains(DateTime(2026, 12, 1)), isTrue);
      expect(christmas.contains(DateTime(2026, 12, 31, 23, 30)), isTrue);
      expect(christmas.contains(DateTime(2027, 1, 1)), isTrue);
      expect(christmas.contains(DateTime(2027, 1, 6)), isTrue);
      expect(christmas.contains(DateTime(2027, 1, 7)), isFalse);
    });

    test('detects an overlap inside a wrapping window', () {
      const advent = AppearanceWindow(
        fromMonth: 12,
        fromDay: 15,
        untilMonth: 12,
        untilDay: 25,
      );
      expect(christmas.overlaps(advent), isTrue);
      const summer = AppearanceWindow(
        fromMonth: 6,
        fromDay: 1,
        untilMonth: 6,
        untilDay: 2,
      );
      expect(christmas.overlaps(summer), isFalse);
    });
  });

  group('AppearanceCatalog.parseDocuments', () {
    test('bundled garden manifest matches the built-in pack', () async {
      final catalog = await AppearanceCatalog.load(rootBundle);
      expect(catalog.garden, AppearancePack.garden);
      expect(catalog.seasons, isEmpty);
    });

    test('a season inherits omitted slots and resolves relative art', () {
      final catalog = AppearanceCatalog.parseDocuments([
        _gardenDocument(),
        AppearanceManifest(
          directory: 'assets/themes/christmas',
          json: {
            'id': 'christmas',
            'name': 'Christmas',
            'schema': 1,
            'window': {'from': '12-01', 'until': '01-06'},
            'assets': {'home.hero': 'hero.png'},
            'colors': {
              'light': {'primary': '#1B4332'},
            },
          },
        ),
      ]);

      expect(catalog.seasons, hasLength(1));
      final christmas = catalog.seasons.single;
      expect(
        christmas.asset(AppearanceSlot.homeHero),
        'assets/themes/christmas/hero.png',
      );
      expect(
        christmas.asset(AppearanceSlot.homeFrameLight),
        AppearancePack.garden.asset(AppearanceSlot.homeFrameLight),
      );
      expect(christmas.lightColors.primary, const Color(0xFF1B4332));
      expect(christmas.vineSkins, AppearancePack.garden.vineSkins);
      expect(
        catalog.resolve(AppearancePack.autoSelection, DateTime(2026, 12, 1)).id,
        'christmas',
      );
      expect(
        catalog
            .resolve(AppearancePack.autoSelection, DateTime(2026, 11, 30))
            .id,
        'garden',
      );
      expect(
        catalog.resolve('garden', DateTime(2026, 12, 25)).id,
        'garden',
      );
      expect(catalog.resolve('missing', DateTime(2026, 12, 25)).id, 'garden');
    });

    test('drops an unknown schema and a low-contrast primary', () {
      final catalog = AppearanceCatalog.parseDocuments([
        AppearanceManifest(
          directory: 'assets/themes/future',
          json: {
            'id': 'future',
            'name': 'Future',
            'schema': 99,
          },
        ),
        AppearanceManifest(
          directory: 'assets/themes/wash',
          json: {
            'id': 'wash',
            'name': 'Wash',
            'schema': 1,
            'colors': {
              'light': {'primary': '#FFFFFF'},
            },
          },
        ),
      ]);

      expect(catalog.garden, AppearancePack.garden);
      expect(catalog.seasons, isEmpty);
    });

    test('drops the later of two overlapping windows', () {
      final catalog = AppearanceCatalog.parseDocuments([
        _season('yuletide', from: '12-20', until: '12-26'),
        _season('advent', from: '12-01', until: '01-06'),
      ]);

      expect(catalog.seasons.map((pack) => pack.id), ['advent']);
    });

    test('an incomplete garden manifest keeps the built-in garden', () {
      final catalog = AppearanceCatalog.parseDocuments([
        const AppearanceManifest(
          directory: 'assets/themes/garden',
          json: {
            'id': 'garden',
            'name': 'Garden',
            'schema': 1,
            'assets': {'home.hero': 'assets/art/home/cross_wood.png'},
          },
        ),
      ]);

      expect(catalog.garden, AppearancePack.garden);
    });
  });

  group('appearance providers', () {
    late _MemoryBox box;

    setUp(() {
      box = _MemoryBox();
    });

    test('auto follows the clock and an explicit pack wins', () async {
      final catalog = AppearanceCatalog.parseDocuments([
        _season('christmas', from: '12-01', until: '01-06'),
      ]);
      final container = _container(
        box,
        catalog: catalog,
        now: DateTime(2026, 12, 2),
      );
      addTearDown(container.dispose);
      await container.read(appearanceCatalogProvider.future);

      expect(container.read(resolvedAppearancePackProvider).id, 'christmas');
      await container
          .read(appearanceSelectionProvider.notifier)
          .setSelection('garden');
      expect(container.read(resolvedAppearancePackProvider).id, 'garden');
      expect(box.store['appearancePack'], 'garden');
    });

    test('legacy vine style maps onto the garden skin', () {
      box.store['vineStyle'] = 'classic';
      final container = _container(box);
      addTearDown(container.dispose);

      expect(container.read(activeVineSkinProvider).id, 'trellis');
    });

    test('a saved skin stays on its own pack', () async {
      box.store['vineSkinByPack'] = {'garden': 'flat'};
      final container = _container(box);
      addTearDown(container.dispose);

      expect(container.read(activeVineSkinProvider).id, 'flat');
      await container
          .read(vineSkinByPackProvider.notifier)
          .setSkin('christmas', 'trellis');
      expect(container.read(vineSkinByPackProvider)['garden'], 'flat');
      expect(container.read(vineSkinByPackProvider)['christmas'], 'trellis');
    });
  });

  testWidgets('level complete reads the sprig slot from the scope',
      (tester) async {
    const pack = AppearancePack(
      id: 'fixture',
      name: 'Fixture',
      assets: {
        AppearanceSlot.homeGrain: 'assets/art/home/parchment.png',
        AppearanceSlot.homeFrameLight: 'assets/art/home/frame_light.png',
        AppearanceSlot.homeFrameDark: 'assets/art/home/frame_dark.png',
        AppearanceSlot.homeHero: 'assets/art/home/cross_wood.png',
        AppearanceSlot.ornamentSprig: 'assets/art/home/cross_wood.png',
        AppearanceSlot.ornamentDivider: 'assets/art/ornaments/leaf_pair.png',
        AppearanceSlot.boardDay: 'assets/art/bg_day_new.png',
        AppearanceSlot.boardNight: 'assets/art/bg_night_new.png',
      },
      vineSkins: [
        VineSkin(
          id: 'flat',
          label: 'Flat',
          flat: true,
          foliage: VineFoliage.none,
        ),
      ],
      defaultVineSkinId: 'flat',
    );

    await tester.pumpWidget(
      AppearanceScope(
        pack: pack,
        child: const MaterialApp(
          home: Scaffold(
            body: LevelCompleteOverlay(message: 'Well done!'),
          ),
        ),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName.endsWith('cross_wood.png'),
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName.contains('leaf_sprig'),
      ),
      findsNothing,
    );
  });
}

AppearanceManifest _gardenDocument() {
  return const AppearanceManifest(
    directory: 'assets/themes/garden',
    json: {
      'id': 'garden',
      'name': 'Garden',
      'schema': 1,
      'assets': {
        'home.grain': 'assets/art/home/parchment.png',
        'home.frame.light': 'assets/art/home/frame_light.png',
        'home.frame.dark': 'assets/art/home/frame_dark.png',
        'home.hero': 'assets/art/home/cross_wood.png',
        'ornament.sprig': 'assets/art/ornaments/leaf_sprig.png',
        'ornament.divider': 'assets/art/ornaments/leaf_pair.png',
        'board.day': 'assets/art/bg_day_new.png',
        'board.night': 'assets/art/bg_night_new.png',
      },
    },
  );
}

AppearanceManifest _season(
  String id, {
  required String from,
  required String until,
}) {
  return AppearanceManifest(
    directory: 'assets/themes/$id',
    json: {
      'id': id,
      'name': id,
      'schema': 1,
      'window': {'from': from, 'until': until},
    },
  );
}

ProviderContainer _container(
  _MemoryBox box, {
  AppearanceCatalog? catalog,
  DateTime? now,
}) {
  return ProviderContainer(
    overrides: [
      hiveBoxProvider.overrideWithValue(box),
      if (catalog != null)
        appearanceCatalogProvider.overrideWith((ref) async => catalog),
      if (now != null) appearanceClockProvider.overrideWithValue(() => now),
    ],
  );
}

class _MemoryBox implements Box<dynamic> {
  final Map<dynamic, dynamic> store = {};

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      store.containsKey(key) ? store[key] : defaultValue;

  @override
  Future<void> put(dynamic key, dynamic value) async => store[key] = value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
