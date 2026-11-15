package utils

import (
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/config"
)

// ProfileForSlot returns the variety profile for a tier slot.
// Slot 0 is the short, mostly-free opener. Later slots wind more and
// aim fewer heads straight off the board. The boss matches slot 4.
func ProfileForSlot(difficulty string, slot int, challenge bool) config.VarietyProfile {
	profile := GetPresetProfile(difficulty)
	if challenge {
		slot = 4
	}
	if slot < 0 {
		slot = 0
	}
	if slot > 4 {
		slot = 4
	}

	switch slot {
	case 0:
		profile.TurnMix = 0.35
		profile.RegionBias = "edge"
		profile.FreeHeadBias = 0.85
		profile.LengthMix = map[string]float64{"short": 0.1, "medium": 0.35, "long": 0.55}
	case 1:
		profile.TurnMix = 0.45
		profile.RegionBias = "balanced"
		profile.FreeHeadBias = 0.7
		profile.LengthMix = map[string]float64{"short": 0.1, "medium": 0.4, "long": 0.5}
	case 2:
		profile.TurnMix = 0.4
		profile.RegionBias = "center"
		profile.FreeHeadBias = 0.55
		profile.LengthMix = map[string]float64{"short": 0.1, "medium": 0.35, "long": 0.55}
	case 3:
		profile.TurnMix = 0.25
		profile.RegionBias = "edge"
		profile.FreeHeadBias = 0.35
		profile.LengthMix = map[string]float64{"short": 0.05, "medium": 0.25, "long": 0.7}
	default:
		profile.TurnMix = 0.7
		profile.RegionBias = "balanced"
		profile.FreeHeadBias = 0.2
		profile.LengthMix = map[string]float64{"short": 0.05, "medium": 0.3, "long": 0.65}
	}
	return profile
}

// AnchorRatioForSlot is the clearable-first share of outward edge anchors.
// Early slots keep more immediately free vines. Later slots and the boss do not.
func AnchorRatioForSlot(slot int, challenge bool) float64 {
	if challenge {
		return 0.12
	}
	switch slot {
	case 0:
		return 0.45
	case 1:
		return 0.35
	case 2:
		return 0.25
	case 3:
		return 0.18
	default:
		return 0.12
	}
}

// MotifForSlot picks the placement strategy and the motif name recorded in stats.
// Slot 3 and 4 reuse existing strategies with a different profile.
func MotifForSlot(slot int, challenge bool) (strategy string, motif string) {
	if challenge {
		return config.StrategyLegacyClearable, "boss-knot"
	}
	switch slot {
	case 0:
		return config.StrategyLegacyClearable, "edge-anchor"
	case 1:
		return config.StrategyDirectionFirst, "direction-first"
	case 2:
		return config.StrategyCenterOut, "center-out"
	case 3:
		return config.StrategyLegacyClearable, "border-frame"
	default:
		return config.StrategyDirectionFirst, "winding"
	}
}

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

// GridSizeForLevel returns the scheduled grid for a level ID.
func GridSizeForLevel(levelID int) []int {
	w, h := common.ExpectedGrid(levelID)
	return []int{w, h}
}
