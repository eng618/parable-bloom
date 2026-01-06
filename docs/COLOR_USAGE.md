# Color Usage Guidelines

## Rule: All colors must be defined in const files

To maintain consistency and enable theme-aware design across the application, all color values must be defined as constants in the appropriate files.

### Color Const Files

1. **`lib/core/app_theme.dart`** - Primary theme colors
   - Brand colors (primary, secondary, tertiary)
   - Game-specific colors (vines, grid dots, tap effects)
   - Light/dark theme surface colors
   - Helper methods for brightness-based color selection

2. **`lib/core/vine_color_palette.dart`** - Vine color variations
   - Level-specific vine colors
   - Extended color palette for variety

### Best Practices

- **Never** use hardcoded `Color()` values directly in widgets or components
- **Always** reference colors from `AppTheme` or `VineColorPalette`
- For theme-aware colors, use `AppTheme.get*()` helper methods
- When adding new colors:
  1. Define constants in `app_theme.dart` with clear documentation
  2. Add light/dark variants if theme-dependent
  3. Create a helper method if the color needs brightness-based selection

### Example: Tap Effect Colors

The tap effect demonstrates proper theme-aware color usage:

```dart
// 1. Define in AppTheme
static const Color tapEffectLight = Color(0xFF1C1B1F); // Dark gray
static const Color tapEffectDark = Color(0xFFE6E1E5); // Light gray

// 2. Add helper method
static Color getTapEffectColor(Brightness brightness) {
  return brightness == Brightness.dark ? tapEffectDark : tapEffectLight;
}

// 3. Use in components via theme tracking
final tapEffectColor = AppTheme.getTapEffectColor(
  Theme.of(context).brightness,
);
```

This ensures:

- ✅ Visibility in both light and dark modes
- ✅ Centralized color management
- ✅ Easy theme updates across the app
- ✅ Consistent visual design

---

## Blocked Vine Colors (Reserved)

To make blocked/failed vines visually unambiguous across themes, the app reserves the **attempted/failed** color in `AppTheme` and exposes it to renderers via `GardenGame`:

- `AppTheme.vineAttemptedLight` — reserved attempted/error color for **light** theme (black)
- `AppTheme.vineAttemptedDark` — reserved attempted/error color for **dark** theme (white)
- `AppTheme.getVineAttemptedColor(Brightness)` — helper to pick the correct variant

Guidelines:

- **Do not** add these colors to `VineColorPalette.colors` — they are reserved and must never be used as a regular vine color.
- **Do not** use these values for any non-error visuals (tap effects, grid dots, backgrounds, etc.).
- Blocked appearance is persistent: once a vine has been attempted and was blocked, it **remains shown with the attempted/error color for the rest of the level** (until the level resets or completes). This ensures the player can easily see which vines previously caused a failed attempt.
- Tests assert that these attempted colors are not present in the vine palette and that no level's `vine_color` resolves to them (`test/blocked_vine_color_test.dart`).
- Rendering components should consume `GardenGame.vineAttemptedColor` (updated by `GameScreen`) rather than referencing `AppTheme` directly.

Rationale:

- A distinct, reserved blocked color improves clarity when a vine is blocked so players can immediately recognize the error state regardless of the selected vine color or theme.

Example usage (rendering code should use `GardenGame.vineAttemptedColor` which is populated from the theme):

```dart
final attempted = AppTheme.getVineAttemptedColor(Theme.of(context).brightness);
// Use `attempted` only for attempted/failed vine heads; renderers should read
// `GardenGame.vineAttemptedColor` instead of calling AppTheme directly.
```
