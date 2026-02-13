package config

import (
	math_rand "math/rand"
	"time"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/validator"
)

// BlockingAnalysis contains blocking relationship data
type BlockingAnalysis struct {
	MaxDepth       int
	HasCircular    bool
	CircularChains [][]string
}

// BlockingAnalyzer defines the interface for blocking relationship analysis
type BlockingAnalyzer interface {
	AnalyzeBlocking(vines []model.Vine, occupied map[string]string) (BlockingAnalysis, error)
}

const (
	StrategyDirectionFirst  = "direction-first"
	StrategyCenterOut       = "center-out"       // LIFO
	StrategyLegacyClearable = "legacy-clearable" // Optimized ClearableFirst
)

// GenerationConfig holds configuration for level generation
type GenerationConfig struct {
	LevelID     int
	GridWidth   int
	GridHeight  int
	VineCount   int
	MaxMoves    int
	OutputFile  string
	Randomize   bool
	Seed        int64
	Overwrite   bool
	MinCoverage float64 // Minimum grid coverage required (0.0-1.0)
	Difficulty  string  // Difficulty tier (Seedling, Sprout, etc.)
	Strategy    string  // Placement strategy (direction-first or center-out)

	// Local backtracking configuration
	BacktrackWindow      int    // How many previous vines to remove when attempting local recovery (default 3)
	MaxBacktrackAttempts int    // How many local backtrack retries to attempt per failure (default 2)
	DumpDir              string // Directory to write deterministic failure dumps (if empty, defaults to tools/level-builder/failing_dumps)
}

// GenerationStats tracks performance and quality metrics
type GenerationStats struct {
	PlacementAttempts    int
	BacktracksAttempted  int // total local backtrack attempts
	DumpsProduced        int // deterministic failure dumps written
	SolvabilityChecks    validator.SolvabilityStats
	MaxBlockingDepth     int
	TotalBlockingDepth   int // accumulated for averaging
	BlockingDepthSamples int // samples counted for averaging
	GridCoverage         float64
	GenerationTime       time.Duration
}

// VinePlacementStrategy defines the interface for vine placement algorithms
type VinePlacementStrategy interface {
	PlaceVines(config GenerationConfig, rng *math_rand.Rand, stats *GenerationStats) ([]model.Vine, map[string]string, error)
}

// Assembler defines the interface for assembling final level data
type Assembler interface {
	AssembleLevel(config GenerationConfig, vines []model.Vine, mask *model.Mask, seed int64) model.Level
}
