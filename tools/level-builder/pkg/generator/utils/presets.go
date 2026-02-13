package utils

import (
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/config"
)

// GetPresetProfile returns a VarietyProfile tuned for the given difficulty tier.
func GetPresetProfile(difficulty string) config.VarietyProfile {
	spec := config.DifficultySpecs[difficulty]
	minL, maxL := spec.AvgLengthRange[0], spec.AvgLengthRange[1]
	median := (minL + maxL) / 2

	var lengthMix map[string]float64
	var turnMix float64
	var regionBias string
	dirBalance := map[string]float64{"right": 0.25, "left": 0.25, "up": 0.25, "down": 0.25}

	// Adjust length mix depending on median length
	if median >= 6 {
		// Favor longer vines
		lengthMix = map[string]float64{"short": 0.15, "medium": 0.35, "long": 0.5}
		turnMix = 0.3 // Much lower to encourage straight growth for better occupancy
		regionBias = "edge"
	} else if median <= 4 {
		// Favor shorter vines
		lengthMix = map[string]float64{"short": 0.6, "medium": 0.3, "long": 0.1}
		turnMix = 0.4 // Much lower to encourage straight growth for better occupancy
		regionBias = "center"
	} else {
		// Medium lengths
		lengthMix = map[string]float64{"short": 0.3, "medium": 0.5, "long": 0.2}
		turnMix = 0.35 // Much lower to encourage straight growth for better occupancy
		regionBias = "balanced"
	}

	return config.VarietyProfile{
		LengthMix:  lengthMix,
		TurnMix:    turnMix,
		RegionBias: regionBias,
		DirBalance: dirBalance,
	}
}

// GetGeneratorConfigForDifficulty returns tuned generator parameters for a difficulty tier.
func GetGeneratorConfigForDifficulty(difficulty string) config.GeneratorConfig {
	switch difficulty {
	case "Tutorial":
		return config.GeneratorConfig{MaxSeedRetries: 8, LocalRepairRadius: 1, RepairRetries: 1}
	case "Seedling":
		return config.GeneratorConfig{MaxSeedRetries: 12, LocalRepairRadius: 1, RepairRetries: 2}
	case "Sprout":
		return config.GeneratorConfig{MaxSeedRetries: 20, LocalRepairRadius: 2, RepairRetries: 3}
	case "Nurturing":
		return config.GeneratorConfig{MaxSeedRetries: 40, LocalRepairRadius: 3, RepairRetries: 4}
	case "Flourishing":
		return config.GeneratorConfig{MaxSeedRetries: 60, LocalRepairRadius: 4, RepairRetries: 6}
	case "Transcendent":
		return config.GeneratorConfig{MaxSeedRetries: 120, LocalRepairRadius: 5, RepairRetries: 8}
	default:
		return config.GeneratorConfig{MaxSeedRetries: 20, LocalRepairRadius: 2, RepairRetries: 3}
	}
}

// GraceForDifficulty returns the default grace value for a difficulty.
func GraceForDifficulty(difficulty string) int {
	if spec, ok := config.DifficultySpecs[difficulty]; ok {
		return spec.DefaultGrace
	}
	return 3
}

// DefaultGridSize returns default grid size for a difficulty (used when not specified).
func DefaultGridSize(difficulty string) []int {
	ranges, ok := config.GridSizeRanges[difficulty]
	if !ok {
		return []int{9, 12}
	}
	// Return middle of range
	w := (ranges.MinW + ranges.MaxW) / 2
	h := (ranges.MinH + ranges.MaxH) / 2
	return []int{w, h}
}

// GridSizeForLevel returns the appropriate grid size for a level ID.
func GridSizeForLevel(levelID int) []int {
	// This needs to be imported or duplicated. For now, let's duplicate the logic.
	// TODO: Consider moving DifficultyForLevel to generator or creating a shared constant.
	difficulty := difficultyForLevel(levelID)
	return DefaultGridSize(difficulty)
}

// difficultyForLevel returns the difficulty tier for a given level ID.
// Duplicated from common/utils.go to avoid import cycle.
func difficultyForLevel(levelID int) string {
	switch {
	case levelID <= 5:
		return "Tutorial"
	case levelID <= 15:
		return "Seedling"
	case levelID <= 30:
		return "Sprout"
	case levelID <= 44:
		return "Nurturing"
	case levelID <= 50:
		return "Flourishing"
	default:
		return "Transcendent"
	}
}
