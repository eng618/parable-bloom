/// Art slots a season may replace.
///
/// Widgets ask for a slot. The active pack answers with a Flutter asset key.
/// Biblical themes and the light/dark brightness setting are not slots.
enum AppearanceSlot {
  /// Parchment grain behind Home and the level-complete card.
  homeGrain('home.grain'),

  /// Botanical frame on a light scaffold.
  homeFrameLight('home.frame.light'),

  /// Botanical frame on a dark scaffold.
  homeFrameDark('home.frame.dark'),

  /// Home hero. Garden uses the wooden cross.
  homeHero('home.hero'),

  /// Optional dark-scaffold hero. Falls back to [homeHero].
  homeHeroDark('home.hero.dark'),

  /// Header ornament on the level-complete card.
  ornamentSprig('ornament.sprig'),

  /// Center ornament on the garden leaf divider.
  ornamentDivider('ornament.divider'),

  /// Board plate for a light game background.
  boardDay('board.day'),

  /// Board plate for a dark game background.
  boardNight('board.night');

  const AppearanceSlot(this.key);

  /// Manifest key. Stable across packs.
  final String key;

  static AppearanceSlot? byKey(String key) {
    for (final slot in values) {
      if (slot.key == key) return slot;
    }
    return null;
  }

  /// Slots a garden manifest must set. [homeHeroDark] is optional.
  static const List<AppearanceSlot> required = [
    homeGrain,
    homeFrameLight,
    homeFrameDark,
    homeHero,
    ornamentSprig,
    ornamentDivider,
    boardDay,
    boardNight,
  ];
}
