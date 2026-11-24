# Appearance Packs

Reference for the visual season engine. An appearance pack swaps bundled art and a few palette roles. It is not a biblical theme, and it is not the light / dark / system brightness setting.

Date: 2026-11-23

## Three settings that stay separate

| Setting        | Storage                                                | What it changes                                       |
| -------------- | ------------------------------------------------------ | ----------------------------------------------------- |
| Brightness     | Hive `themeMode` (`light`, `dark`, `system`)           | `AppTheme.lightTheme` / `darkTheme`                   |
| Season         | Hive `appearancePack` (`auto`, `garden`, or a pack id) | Art slots and optional primary / secondary / tertiary |
| Biblical theme | Content registries                                     | Scripture, journal passages, module copy              |

Settings labels them Theme, Season, and the journal's own theme names. Code calls the season an appearance pack.

## Pack layout

Each pack is a `pack.json` plus images under `assets/themes/<id>/`. Flutter does not recurse asset folders, so each pack directory is listed in `apps/parable-bloom/pubspec.yaml`.

The garden pack is schema 1 and points at the existing files under `assets/art/`. Those files are not copied. A later season overrides only the slots it ships. Missing slots keep the garden file.

```
assets/themes/garden/pack.json
assets/themes/christmas/pack.json
assets/themes/christmas/hero.png
assets/themes/christmas/frame_light.png
assets/themes/christmas/frame_dark.png
assets/themes/christmas/sprig.png
assets/themes/christmas/divider.png
assets/themes/christmas/trellis.png
```

Unknown `schema` values are ignored. The app stays on garden.

The Christmas pack ships with the app. Its window is 1 December through 6 January. Parchment grain and both board plates stay on the garden files. There is no dark hero: the oak cross is painted on a transparent ground.

### Manifest

```json
{
  "id": "christmas",
  "name": "Christmas",
  "schema": 1,
  "window": { "from": "12-01", "until": "01-06" },
  "colors": {
    "light": { "primary": "#1B4332", "secondary": "#9B3A3A", "tertiary": "#C6A15B" },
    "dark": { "primary": "#C5D5C0", "secondary": "#E7B7B0", "tertiary": "#E2C98A" }
  },
  "assets": {
    "home.hero": "hero.png",
    "home.frame.light": "frame_light.png",
    "home.frame.dark": "frame_dark.png",
    "ornament.sprig": "sprig.png",
    "ornament.divider": "divider.png"
  },
  "vineSkins": [
    {
      "id": "trellis",
      "label": "Evergreen",
      "texture": "trellis.png",
      "foliage": "leaves",
      "accent": "#C6A15B"
    },
    {
      "id": "flat",
      "label": "Flat",
      "flat": true,
      "foliage": "none",
      "accent": "#C6A15B"
    }
  ],
  "defaultVineSkin": "trellis"
}
```

`window` is month-day, local time, both ends inclusive, and it recurs every year. A window that starts in December and ends in January wraps the new year. Two windows that overlap: the catalog keeps the earlier pack id and drops the other.

Paths that start with `assets/` are used as written. Any other path is relative to the pack directory.

### Slots

| Key                | Garden file                           | Used by                                       |
| ------------------ | ------------------------------------- | --------------------------------------------- |
| `home.grain`       | `assets/art/home/parchment.png`       | Home, level complete                          |
| `home.frame.light` | `assets/art/home/frame_light.png`     | Home, level complete                          |
| `home.frame.dark`  | `assets/art/home/frame_dark.png`      | Home, level complete                          |
| `home.hero`        | `assets/art/home/cross_wood.png`      | Home                                          |
| `home.hero.dark`   | omitted                               | Home, when the light hero fails on night soil |
| `ornament.sprig`   | `assets/art/ornaments/leaf_sprig.png` | Level complete                                |
| `ornament.divider` | `assets/art/ornaments/leaf_pair.png`  | Level complete divider                        |
| `board.day`        | `assets/art/bg_day_new.png`           | Flame board plate                             |
| `board.night`      | `assets/art/bg_night_new.png`         | Flame board plate                             |

Widgets read slots through `AppearanceScope` and `ThemedAsset`. With no scope mounted, the scope returns the built-in garden pack.

`GardenLeafDivider` draws `ornament.divider` at the full width of the card, in the colors painted in the file. The asset is a wide rule, so a fixed height would shrink it into the middle.

Board plates load through `GardenGame.applyBoardBackgrounds`. Keys under `assets/art/` use the Flame image cache. A season file outside that prefix is decoded from the asset bundle.

## Color rules

`AppTheme.forPack` starts from the garden theme. A pack may set `primary`, `secondary`, and `tertiary` for each brightness. Surfaces, ink, error, type, and the blocked-vine colors stay on the garden values. Roles that already match the garden seeds leave `lightTheme` / `darkTheme` as the same instance.

A pack whose primary fails WCAG AA for large text (contrast below 3.0) against the scaffold, the surface, or the button label (`onPrimary`) is dropped. The season does not load.

## How a season turns on

1. An explicit pack id, when that pack is in the binary.
2. `auto` (the default): the bundled pack whose window contains today's local date.
3. Otherwise garden.

An id this build does not contain resolves to garden. The choice is checked when the catalog or the setting changes. It does not tick at midnight while the process stays up.

`SCREENSHOT_MODE` resolves to garden before the selection and the window. `task release:android:screenshots` stays on the garden art in December.

`GardenGame` swaps board plates without rebuilding the game. Vine motion and the solver are not part of a pack.

Settings → Appearance → Season lists Automatic and every loaded pack. Reset data clears the Hive key with the other settings.

## Vine skins

The garden manifest records four skins: `trellis` (the classic wood texture), `blossom`, `ethereal`, and `flat`. Foliage is `leaves`, `blossom`, `glow`, or `none`.

Christmas publishes `trellis` (label Evergreen, candle-gold caps) and `flat`. It does not republish blossom or ethereal. The tube still samples the center columns of the strip, so `trellis.png` keeps wood and evergreen in that sliver. Textured skins stay behind the debug gate below.

Hive `vineSkinByPack` stores a skin id per pack id, so a holiday choice does not replace the garden choice. A legacy `vineStyle` of `classic` reads as garden `trellis`, and `simple` reads as `flat`, when the per-pack map is still empty.

The rail reads `renderedVineSkinProvider`. That skin picks the trellis strip, the foliage recipe, and the cap accent. `VineTextureLoader` loads the strip by asset key. Files under `assets/art/` use the Flame cache. A season file outside that prefix is decoded from the bundle.

`vineTexturedSkins` (Hive, default off) is the play-pass gate. While it is off, Settings and the pause menu offer the flat stroke, and a saved textured skin stays saved. Settings → Debug → Textured Vine Skins turns the preview on. Flat stays selectable on every pack. See [Vine rendering](vine-rendering.md).

## What a pack does not change

Level JSON, the solver, scripture, journal text, audio, the app icon, and the marketing site. Celebration particles keep the garden motion and pick up a primary tint only when the pack changes that role.
