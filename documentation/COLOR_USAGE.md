# Color Usage Guidelines

## Rule: All colors must be defined in const files

To maintain consistency and enable theme-aware design across the application, all color values must be defined as constants in the appropriate files.

### Color Const Files

1. **`lib/core/app_theme.dart`** - Primary theme colors
   - Brand colors (primary, secondary, tertiary)
   - Game-specific colors (vines, grid dots, tap effects)
   - Light/dark theme surface colors
   - Semantic colors (success, error)
   - Helper methods for brightness-based color selection
   - Contrast ratio validation for WCAG AA compliance
   - Dynamic color support for Android 12+

2. **`lib/core/vine_color_palette.dart`** - Vine color variations
   - Level-specific vine colors
   - Extended color palette for variety

3. **`AppThemeExtension`** - Theme extension for game-specific properties
   - Vine colors, grid dots, tap effects with brightness-aware values
   - Accessible via `Theme.of(context).extension<AppThemeExtension>()`

### Best Practices

- **Never** use hardcoded `Color()` values directly in widgets or components
- **Always** reference colors from `AppTheme` or `VineColorPalette`
- For theme-aware colors, use `AppTheme.get*()` helper methods
- For game-specific colors, use `Theme.of(context).extension<AppThemeExtension>()`
- When adding new colors:
  1. Define constants in `app_theme.dart` with clear documentation
  2. Add light/dark variants if theme-dependent
  3. Create a helper method if the color needs brightness-based selection
  4. If game-specific, add to `AppThemeExtension` with proper `copyWith` and `lerp`
  5. Validate contrast ratios using `AppTheme.getContrastRatio()` for WCAG AA compliance
  6. Update this documentation

### Example: Grid Dot Colors

The grid dots demonstrate theme-aware color usage with differentiated variants:

```dart
// 1. Define in AppTheme
static const Color gridDotLight = Color(0x26E2D6C4); // 15% beige
static const Color gridDotDark = Color(0x263A7DAF); // 15% primary blue

// 2. Add helper method
static Color getGridDotColor(Brightness brightness) {
  return brightness == Brightness.dark ? gridDotDark : gridDotLight;
}

// 3. Use in components via theme extension
final gridDotColor = Theme.of(context).extension<AppThemeExtension>()!.gridDot;
```

### Example: Semantic Colors

Success and error colors for game states:

```dart
// Defined in AppTheme
static const Color successColor = secondarySeed; // Green for success
static const Color errorColor = Color(0xFFD32F2F); // Red for errors

// Use in UI feedback
final successTextStyle = TextStyle(color: AppTheme.successColor);
```

### Example: Theme Extension Usage

Access game-specific colors through the extension:

```dart
final extension = Theme.of(context).extension<AppThemeExtension>()!;
final vineColor = extension.vineGreen;
final tapEffect = extension.tapEffect;
```

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
- `AppThemeExtension.vineAttempted` — theme extension property for attempted color

Guidelines:

- **Do not** add these colors to `VineColorPalette.colors` — they are reserved and must never be used as a regular vine color.
- **Do not** use these values for any non-error visuals (tap effects, grid dots, backgrounds, etc.).
- Blocked appearance is persistent: once a vine has been attempted and was blocked, it **remains shown with the attempted/error color for the rest of the level** (until the level resets or completes). This ensures the player can easily see which vines previously caused a failed attempt.
- Tests assert that these attempted colors are not present in the vine palette and that no level's `vine_color` resolves to them (`test/blocked_vine_color_test.dart`).
- Rendering components should consume `GardenGame.vineAttemptedColor` (updated by `GameScreen`) rather than referencing `AppTheme` directly.

Rationale:

- A distinct, reserved blocked color improves clarity when a vine is blocked so players can immediately recognize the error state regardless of the selected vine color or theme.

Example usage (rendering code should use `GardenGame.vineAttemptedColor` which is populated from the theme extension):

```dart
final extension = Theme.of(context).extension<AppThemeExtension>()!;
final attempted = extension.vineAttempted; // Automatically theme-aware
// Use `attempted` only for attempted/failed vine heads; renderers should read
// `GardenGame.vineAttemptedColor` instead of calling AppTheme directly.
```

---

## Adding New Colors in the Future

When introducing new colors to the theme system, follow this structured approach:

### 1. Determine Color Type and Location

- **Brand Colors**: Add to `BRAND COLORS` section in `AppTheme` (rare, affects entire identity)
- **Semantic Colors**: Add to `SEMANTIC COLORS` section for UI states (success, warning, info)
- **Game-Specific Colors**: Add to `AppThemeExtension` for Flame/game rendering
- **Theme Variants**: Add light/dark pairs in theme color sections if needed

### 2. Implementation Steps

1. **Define Constants**: Add `static const Color` with clear documentation
2. **Add Helpers**: Create `get*Color(Brightness)` if theme-dependent
3. **Update Extension**: If game-specific, add to `AppThemeExtension` with `copyWith`/`lerp`
4. **Apply to Themes**: Include in `lightTheme`/`darkTheme` via `extensions` or `copyWith`
5. **Validate Contrast**: Use `AppTheme.getContrastRatio()` to ensure WCAG AA compliance
6. **Update Docs**: Add to this document with examples

### 3. Example: Adding a Warning Color

```dart
// In AppTheme
static const Color warningColor = Color(0xFFFFA000); // Amber for warnings

// In themes (if needed for outlines)
copyWith(outline: warningColor)

// Usage
Text('Warning', style: TextStyle(color: AppTheme.warningColor));
```

### 4. Dynamic Color Considerations

For Android 12+ dynamic color support:

- Use `AppTheme.getDynamicColorScheme()` to get system-based schemes
- Fallback to static themes if dynamic fails
- Test on devices with wallpaper theming enabled

### 5. Testing Requirements

- Add contrast ratio tests for new colors
- Verify visibility in both light/dark themes
- Test with dynamic color enabled/disabled
- Update blocked vine color tests if new reserved colors added
