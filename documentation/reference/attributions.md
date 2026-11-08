# Attributions

## Audio

Paths are under `apps/parable-bloom/`.

| Asset                                                                                                          | Source                                                                                                                                | License                                                     |
| -------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------- |
| `assets/audio/background.mp3`                                                                                  | [ViraMiller on Freesound](https://freesound.org/people/ViraMiller/sounds/744064/)                                                     | CC BY 4.0 (<https://creativecommons.org/licenses/by/4.0/>)  |
| `assets/audio/sfx/grace_loss.mp3`, `level_complete.mp3`, `ui_tap.mp3`, and `assets/audio/sfx/vines/vine_*.mp3` | Original procedural SFX authored for Parable Bloom                                                                                    | Copyright © 2026 Eric Garcia (GVTech). All rights reserved. |
| `assets/audio/sfx/ui/`                                                                                         | [Case Portman UI SFX (Free Sample Pack)](https://caseportman.itch.io/cute-cozy-ui-sfx-free-sample-pack). Credit: “Case Portman Audio” | Royalty-free. Commercial use allowed. Attribution required. |
| `assets/audio/sfx/nature/` and `assets/audio/sfx/vines/vine_foliage_rustle_*.wav`                              | [Nature Sounds Pack by Antoinemax](https://opengameart.org/content/nature-sounds-pack)                                                | CC-BY 4.0 (<https://creativecommons.org/licenses/by/4.0/>)  |

Foliage clips from the Nature Sounds Pack live in `sfx/vines/` so they can be used later for vine rustle. They are not wired into playback yet. The in-app list is Settings → About → Audio credits. The website mirrors these notices at `/attributions`.

## Fonts

| Font Family       | Source                                                                          | License                         |
| ----------------- | ------------------------------------------------------------------------------- | ------------------------------- |
| **Fraunces**      | [Google Fonts - Fraunces](https://fonts.google.com/specimen/Fraunces)           | SIL Open Font License 1.1 (OFL) |
| **Alegreya Sans** | [Google Fonts - Alegreya Sans](https://fonts.google.com/specimen/Alegreya+Sans) | SIL Open Font License 1.1 (OFL) |

## Visual Assets

All in-game and website visual assets, including:

- App Icons (`app_icon.png`, `app_icon_branded.png`)
- Watercolor Backgrounds (`bg_day_new.png`, `bg_night_new.png`)
- Vine Textures (`classic_vine_texture.png`, `blossom_vine_texture.png`, `ethereal_vine_texture.png`)
- Decorative artwork and grid cells

Are custom creations designed specifically for Parable Bloom.
**Copyright © 2026 Eric Garcia (GVTech). All rights reserved.**

## Scripture Translations

Default: **NET Bible** (gratis ministry use in this free app, verse text only). Also supported: **WEB** and **BSB** (public domain, on-demand download then offline), **KJV** (bundled fallback).

App bundle ships NET + KJV only; WEB/BSB are fetched once from Firestore `scriptures_{env}` and cached in Hive. Every citation opens its full notice in-app; the website mirrors all notices at `/attributions`.

For the exact copyright notices, permissions limits, API configurations, and compliance safeguards, please refer to the detailed [Scripture Licensing & Compliance Guide](scripture-licensing.md).
