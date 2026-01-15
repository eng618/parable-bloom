package gen2

import (
	"fmt"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

// TranscendentAssembler implements LevelAssembler for transcendent levels
type TranscendentAssembler struct{}

// convertCommonPointsToModel converts []common.Point to []model.Point
func convertCommonPointsToModel(commonPoints []model.Point) []model.Point {
	modelPoints := make([]model.Point, len(commonPoints))
	for i, p := range commonPoints {
		modelPoints[i] = model.Point{X: p.X, Y: p.Y}
	}
	return modelPoints
}

// AssembleLevel creates the final level data structure
func (a *TranscendentAssembler) AssembleLevel(config GenerationConfig, vines []model.Vine, mask *model.Mask, seed int64) model.Level {
	// Convert vines to model format
	modelVines := make([]model.Vine, len(vines))
	for i, v := range vines {
		modelVines[i] = model.Vine{
			ID:            v.ID,
			HeadDirection: v.HeadDirection,
			OrderedPath:   convertCommonPointsToModel(v.OrderedPath),
		}
	}

	// Generate color scheme (simplified for now)
	colorScheme := a.generateColorScheme(len(vines))

	// Create mask in model format
	var modelMask *model.Mask
	if mask != nil {
		modelMask = &model.Mask{
			Mode:   mask.Mode,
			Points: convertCommonPointsToModel(mask.Points),
		}
	}

	// Estimate min moves (conservative)
	minMoves := len(vines) / 2
	if minMoves < 1 {
		minMoves = 1
	}

	level := model.Level{
		ID:          config.LevelID,
		Name:        fmt.Sprintf("Transcendent Level %d", config.LevelID),
		Difficulty:  "Transcendent",
		GridSize:    []int{config.GridWidth, config.GridHeight},
		Vines:       modelVines,
		MaxMoves:    config.MaxMoves,
		MinMoves:    minMoves,
		Complexity:  "extreme",
		Grace:       4, // Transcendent gets 4 grace
		ColorScheme: colorScheme,
		Mask:        modelMask,
		Seed:        seed, // Add seed to level metadata
	}

	return level
}

// generateColorScheme creates a color palette for the level
func (a *TranscendentAssembler) generateColorScheme(vineCount int) []string {
	// Transcendent color scheme - rich, complex colors
	baseColors := []string{
		"#8B4513", // Saddle Brown (foundation)
		"#FF6347", // Tomato (intermediate)
		"#FFD700", // Gold (quick-clear)
		"#8A2BE2", // Blue Violet (complex)
		"#00CED1", // Dark Turquoise (alternative)
		"#DC143C", // Crimson (deep blocking)
		"#32CD32", // Lime Green (strategic)
		"#FF1493", // Deep Pink (boss vines)
	}

	colors := make([]string, vineCount)
	for i := range colors {
		colors[i] = baseColors[i%len(baseColors)]
	}

	return colors
}
