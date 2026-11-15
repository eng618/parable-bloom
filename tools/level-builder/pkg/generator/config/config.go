package config

import (
	"time"
)

// ModuleRange represents a difficulty tier range with module context.
// Used internally for generation; not serialized.
type ModuleRange struct {
	ID    int
	Name  string
	Start int
	End   int
}

// ValidationResult holds the results of level validation.
type ValidationResult struct {
	Filename   string
	Violations []string
	Warnings   []string
	Valid      bool
	Timestamp  time.Time
}

// DifficultySpec defines constraints for a difficulty tier.
type DifficultySpec struct {
	VineCountRange   [2]int
	AvgLengthRange   [2]int
	MaxBlockingDepth int
	ColorCountRange  [2]int
	MinGridOccupancy float64
	DefaultGrace     int
}

// DifficultySpecs maps difficulty tier names to their specifications.
var DifficultySpecs = map[string]DifficultySpec{
	"Tutorial": {
		VineCountRange:   [2]int{3, 8},
		AvgLengthRange:   [2]int{6, 10}, // Moderate increase for longer, windier vines
		MaxBlockingDepth: 0,
		ColorCountRange:  [2]int{1, 5},
		MinGridOccupancy: 0.30,
		DefaultGrace:     3,
	},
	"Seedling": {
		VineCountRange:   [2]int{14, 24},
		AvgLengthRange:   [2]int{7, 12},
		MaxBlockingDepth: 1,
		ColorCountRange:  [2]int{1, 5},
		MinGridOccupancy: 0.93,
		DefaultGrace:     3,
	},
	"Sprout": {
		VineCountRange:   [2]int{20, 32},
		AvgLengthRange:   [2]int{8, 14},
		MaxBlockingDepth: 2,
		ColorCountRange:  [2]int{1, 5},
		MinGridOccupancy: 0.93,
		DefaultGrace:     3,
	},
	"Nurturing": {
		VineCountRange:   [2]int{26, 40},
		AvgLengthRange:   [2]int{9, 16},
		MaxBlockingDepth: 3,
		ColorCountRange:  [2]int{1, 6},
		MinGridOccupancy: 0.93,
		DefaultGrace:     3,
	},
	"Flourishing": {
		VineCountRange:   [2]int{34, 52},
		AvgLengthRange:   [2]int{10, 16},
		MaxBlockingDepth: 4,
		ColorCountRange:  [2]int{1, 6},
		MinGridOccupancy: 0.93,
		DefaultGrace:     3,
	},
	"Transcendent": {
		VineCountRange:   [2]int{55, 80},
		AvgLengthRange:   [2]int{12, 18},
		MaxBlockingDepth: 4,
		ColorCountRange:  [2]int{1, 6},
		MinGridOccupancy: 0.93,
		DefaultGrace:     4,
	},
}

// ColorPalette defines the available vine colors.
// Used for generating ColorScheme arrays in levels.
var ColorPalette = []string{
	"#888888", // default - Neutral gray
	"#7CB342", // moss_green
	"#FF9800", // sunset_orange
	"#FFC107", // golden_yellow
	"#7C4DFF", // royal_purple
	"#29B6F6", // sky_blue
	"#FF6E40", // coral_red
	"#CDDC39", // lime_green
}

// GridSizeRanges defines grid size ranges per difficulty tier.
var GridSizeRanges = map[string]struct {
	MinW, MinH, MaxW, MaxH int
}{
	"Tutorial":     {MinW: 5, MinH: 8, MaxW: 9, MaxH: 12},
	"Seedling":     {MinW: 9, MinH: 12, MaxW: 12, MaxH: 16},
	"Sprout":       {MinW: 12, MinH: 16, MaxW: 14, MaxH: 22},
	"Nurturing":    {MinW: 14, MinH: 20, MaxW: 16, MaxH: 26},
	"Flourishing":  {MinW: 16, MinH: 24, MaxW: 18, MaxH: 30},
	"Transcendent": {MinW: 22, MinH: 36, MaxW: 22, MaxH: 36},
}

// VarietyProfile controls shape and distribution characteristics for generated levels.
type VarietyProfile struct {
	LengthMix    map[string]float64 // keys: "short","medium","long" => relative weights
	TurnMix      float64            // 0..1 proportion of turns (bendiness). 0 means the placer default.
	RegionBias   string             // "edge","center","balanced"
	DirBalance   map[string]float64 // desired head dir distribution (right,left,up,down)
	FreeHeadBias float64            // 0..1 chance a new head aims at the nearest edge. 0 means always.
}

// GeneratorConfig holds generation algorithm tuning parameters and safety caps.
type GeneratorConfig struct {
	MaxSeedRetries    int // retries to find a seed that can grow
	LocalRepairRadius int // radius for local repair tiles
	RepairRetries     int // number of local repair attempts per stuck region
}
