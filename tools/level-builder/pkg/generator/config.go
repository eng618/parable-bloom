package generator

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
		AvgLengthRange:   [2]int{6, 8},
		MaxBlockingDepth: 0,
		ColorCountRange:  [2]int{1, 5},
		MinGridOccupancy: 0.30,
		DefaultGrace:     3,
	},
	"Seedling": {
		VineCountRange:   [2]int{4, 60},
		AvgLengthRange:   [2]int{6, 8},
		MaxBlockingDepth: 1,
		ColorCountRange:  [2]int{1, 5},
		MinGridOccupancy: 0.93,
		DefaultGrace:     3,
	},
	"Sprout": {
		VineCountRange:   [2]int{8, 80},
		AvgLengthRange:   [2]int{3, 8},
		MaxBlockingDepth: 2,
		ColorCountRange:  [2]int{1, 5},
		MinGridOccupancy: 0.93,
		DefaultGrace:     3,
	},
	"Nurturing": {
		VineCountRange:   [2]int{12, 100},
		AvgLengthRange:   [2]int{3, 8},
		MaxBlockingDepth: 3,
		ColorCountRange:  [2]int{1, 6},
		MinGridOccupancy: 0.93,
		DefaultGrace:     3,
	},
	"Flourishing": {
		VineCountRange:   [2]int{15, 150},
		AvgLengthRange:   [2]int{2, 6},
		MaxBlockingDepth: 4,
		ColorCountRange:  [2]int{1, 6},
		MinGridOccupancy: 0.93,
		DefaultGrace:     3,
	},
	"Transcendent": {
		VineCountRange:   [2]int{15, 200},
		AvgLengthRange:   [2]int{2, 6},
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
	"Seedling":     {MinW: 6, MinH: 8, MaxW: 9, MaxH: 12},
	"Sprout":       {MinW: 9, MinH: 12, MaxW: 12, MaxH: 16},
	"Nurturing":    {MinW: 9, MinH: 16, MaxW: 12, MaxH: 20},
	"Flourishing":  {MinW: 12, MinH: 20, MaxW: 16, MaxH: 24},
	"Transcendent": {MinW: 16, MinH: 28, MaxW: 24, MaxH: 40},
}

// VarietyProfile controls shape and distribution characteristics for generated levels.
type VarietyProfile struct {
	LengthMix  map[string]float64 // keys: "short","medium","long" => relative weights
	TurnMix    float64            // 0..1 proportion of turns (bendiness)
	RegionBias string             // "edge","center","balanced"
	DirBalance map[string]float64 // desired head dir distribution (right,left,up,down)
}

// GeneratorConfig holds generation algorithm tuning parameters and safety caps.
type GeneratorConfig struct {
	MaxSeedRetries    int // retries to find a seed that can grow
	LocalRepairRadius int // radius for local repair tiles
	RepairRetries     int // number of local repair attempts per stuck region
}
