package generator

import (
	"fmt"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/config"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

// LevelAssembler implements LevelAssembler for all difficulty tiers
type LevelAssembler struct{}

// TODO: does this need to be removed now? There is no actual conversion needed now?
// convertCommonPointsToModel converts []model.Point to []model.Point
func convertCommonPointsToModel(commonPoints []model.Point) []model.Point {
	modelPoints := make([]model.Point, len(commonPoints))
	for i, p := range commonPoints {
		modelPoints[i] = model.Point{X: p.X, Y: p.Y}
	}
	return modelPoints
}

// AssembleLevel creates the final level data structure
func (a *LevelAssembler) AssembleLevel(cfg config.GenerationConfig, vines []model.Vine, mask *model.Mask, seed int64) model.Level {
	// Get difficulty spec for this tier
	spec, ok := config.DifficultySpecs[cfg.Difficulty]
	if !ok {
		// Fallback to Seedling if unknown difficulty
		spec = config.DifficultySpecs["Seedling"]
	}

	// Convert vines to model format with color_index assignment
	modelVines := make([]model.Vine, len(vines))
	colorCount := spec.ColorCountRange[1] // Use max colors from spec
	if colorCount < 1 {
		colorCount = 5
	}

	for i, v := range vines {
		modelVines[i] = model.Vine{
			ID:            v.ID,
			HeadDirection: v.HeadDirection,
			OrderedPath:   convertCommonPointsToModel(v.OrderedPath),
			ColorIndex:    i % colorCount, // 0-based, round-robin assignment
		}
	}

	// Generate color scheme using shared palette
	colorScheme := a.generateColorScheme(colorCount)

	// Create mask in model format
	var modelMask *model.Mask
	if mask != nil {
		modelMask = &model.Mask{
			Mode:   mask.Mode,
			Points: convertCommonPointsToModel(mask.Points),
		}
	}

	// Estimate min moves (conservative)
	minMoves := len(vines)
	if minMoves < 1 {
		minMoves = 1
	}

	// Determine complexity based on difficulty tier
	complexity := a.complexityForDifficulty(cfg.Difficulty)

	level := model.Level{
		ID:          cfg.LevelID,
		Name:        fmt.Sprintf("Level %d", cfg.LevelID),
		Difficulty:  cfg.Difficulty,
		GridSize:    []int{cfg.GridWidth, cfg.GridHeight},
		Vines:       modelVines,
		MaxMoves:    cfg.MaxMoves,
		MinMoves:    minMoves,
		Complexity:  complexity,
		Grace:       spec.DefaultGrace,
		ColorScheme: colorScheme,
		Mask:        modelMask,
		Seed:        seed,
	}

	return level
}

// complexityForDifficulty maps difficulty tier to complexity string
func (a *LevelAssembler) complexityForDifficulty(difficulty string) string {
	switch difficulty {
	case "Tutorial":
		return "simple"
	case "Seedling":
		return "low"
	case "Sprout":
		return "medium"
	case "Nurturing":
		return "medium"
	case "Flourishing":
		return "high"
	case "Transcendent":
		return "extreme"
	default:
		return "medium"
	}
}

// generateColorScheme creates a color palette using the shared ColorPalette
func (a *LevelAssembler) generateColorScheme(colorCount int) []string {
	palette := config.ColorPalette
	if colorCount > len(palette) {
		colorCount = len(palette)
	}
	if colorCount < 1 {
		colorCount = 5
	}

	colors := make([]string, colorCount)
	for i := 0; i < colorCount; i++ {
		colors[i] = palette[i%len(palette)]
	}

	return colors
}
