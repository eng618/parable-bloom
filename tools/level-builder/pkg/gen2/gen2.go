package gen2

import (
	"encoding/json"
	"fmt"
	math_rand "math/rand"
	"os"
	"path/filepath"
	"time"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
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

// GenerateLevel is now a wrapper for GenerateRobust.
func GenerateLevel(config GenerationConfig) (model.Level, GenerationStats, error) {
	level, stats, err := GenerateRobust(config)
	if err != nil {
		return level, stats, err
	}
	if err := writeLevelToFile(level, config); err != nil {
		return level, stats, err
	}
	return level, stats, nil
}

// GenerateLevelLIFO is now a wrapper for GenerateRobust.
func GenerateLevelLIFO(config GenerationConfig) (model.Level, GenerationStats, error) {
	return GenerateLevel(config) // Both use the robust pipeline now
}

// writeLevelToFile writes the level to JSON file
func writeLevelToFile(level model.Level, config GenerationConfig) error {
	outputPath := config.OutputFile
	if outputPath == "" {
		var err error
		outputPath, err = common.LevelFilePath(config.LevelID)
		if err != nil {
			return fmt.Errorf("failed to resolve level file path: %w", err)
		}
	}

	// Check if file exists and overwrite is not enabled
	if !config.Overwrite {
		if _, err := os.Stat(outputPath); err == nil {
			return fmt.Errorf("file already exists: %s (use --overwrite to replace)", outputPath)
		}
	}

	// Ensure directory exists
	dir := filepath.Dir(outputPath)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return fmt.Errorf("failed to create directory: %w", err)
	}

	// Write JSON
	file, err := os.Create(outputPath)
	if err != nil {
		return fmt.Errorf("failed to create file: %w", err)
	}
	defer func() { _ = file.Close() }()

	encoder := json.NewEncoder(file)
	encoder.SetIndent("", "  ")
	if err := encoder.Encode(level); err != nil {
		return fmt.Errorf("failed to encode JSON: %w", err)
	}

	common.Info("Wrote level file: %s", outputPath)
	return nil
}
