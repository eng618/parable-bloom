package batch

import (
	"encoding/json"
	"fmt"
	"os"
	"time"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/config"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/validator"
)

// getCoverageForDifficulty is removed. We now enforce 100% coverage globally.
const targetCoverage = 1.0

// Config holds configuration for batch level generation.
type Config struct {
	ModuleID  int
	UseLIFO   bool
	Overwrite bool
	DryRun    bool
	OutputDir string // Where to write levels (default: assets/levels)
	BaseSeed  int64  // Base seed for deterministic generation (default: levelID * 31337)
	// Batch-level options
	Aggressive  bool
	DumpDir     string
	StatsOut    string  // Optional directory to write per-level stats JSON files
	MinCoverage float64 // Optional override for minimum coverage (0.0-1.0). 0 = no override
	Strategy    string  // Optional strategy override (direction-first, center-out)
}

// Result contains results for a single level in a batch.
type Result struct {
	LevelID       int
	Difficulty    string
	Success       bool
	Error         string
	Coverage      float64
	BlockingDepth int
	GenerationMS  int64
}

// ModuleBatch represents a complete batch of levels for a module.
type ModuleBatch struct {
	ModuleID     int
	Levels       []Result
	TotalTime    time.Duration
	SuccessCount int
	FailureCount int
}

// difficultyTier maps a tier index (0-4) to difficulty name and specs.
type difficultyTier struct {
	Index int
	Name  string
	Specs config.DifficultySpec
}

// getDifficultyTiers returns the 4 non-transcendent difficulty tiers in order.
func getDifficultyTiers() []difficultyTier {
	return []difficultyTier{
		{Index: 0, Name: "Seedling", Specs: config.DifficultySpecs["Seedling"]},
		{Index: 1, Name: "Sprout", Specs: config.DifficultySpecs["Sprout"]},
		{Index: 2, Name: "Nurturing", Specs: config.DifficultySpecs["Nurturing"]},
		{Index: 3, Name: "Flourishing", Specs: config.DifficultySpecs["Flourishing"]},
	}
}

// GenerateModule generates all 21 levels for a module (5 per tier + 1 Transcendent).
// Pattern: levels 1-5 (Seedling), 6-10 (Sprout), 11-15 (Nurturing), 16-20 (Flourishing), 21 (Transcendent).
// For module N, level IDs start at (N-1)*21+1.
func GenerateModule(batchCfg Config) (*ModuleBatch, error) {
	if batchCfg.ModuleID < 1 || batchCfg.ModuleID > 5 {
		return nil, fmt.Errorf("invalid module ID: %d (must be 1-5)", batchCfg.ModuleID)
	}

	if batchCfg.OutputDir == "" {
		batchCfg.OutputDir = "assets/levels"
	}

	startTime := time.Now()
	batch := &ModuleBatch{
		ModuleID: batchCfg.ModuleID,
		Levels:   []Result{},
	}

	startLevelID := (batchCfg.ModuleID-1)*21 + 1

	tiers := getDifficultyTiers()
	for tierIdx, tier := range tiers {
		for levelInTier := 0; levelInTier < 5; levelInTier++ {
			levelID := startLevelID + tierIdx*5 + levelInTier
			result := generateSingleLevel(
				levelID,
				tier.Name,
				batchCfg,
			)
			batch.Levels = append(batch.Levels, result)
			if result.Success {
				batch.SuccessCount++
			} else {
				batch.FailureCount++
			}
		}
	}

	// Transcendent challenge level (position 21)
	challengeLevelID := startLevelID + 20
	result := generateSingleLevel(
		challengeLevelID,
		"Transcendent",
		batchCfg,
	)
	batch.Levels = append(batch.Levels, result)
	if result.Success {
		batch.SuccessCount++
	} else {
		batch.FailureCount++
	}

	batch.TotalTime = time.Since(startTime)

	return batch, nil
}

// generateSingleLevel generates a single level and returns results.
func generateSingleLevel(levelID int, difficulty string, batchCfg Config) Result {
	result := Result{
		LevelID:    levelID,
		Difficulty: difficulty,
	}

	startTime := time.Now()

	var level model.Level
	var stats config.GenerationStats
	var genCfg config.GenerationConfig

	// Strategy Chain:
	// 1. Requested Strategy (from config or auto-determined)
	// 2. Center-Out (LIFO) - strongest solvability guarantee
	// 3. Direction-First - backup for organic shapes

	strategiesToTry := []string{}

	// Determine primary strategy
	primary := determineStrategy(levelID, difficulty, batchCfg)
	strategiesToTry = append(strategiesToTry, primary)

	if primary != config.StrategyCenterOut {
		strategiesToTry = append(strategiesToTry, config.StrategyCenterOut)
	}

	const maxRetriesPerStrategy = 20

	for _, strat := range strategiesToTry {
		for retry := 0; retry < maxRetriesPerStrategy; retry++ {
			var err error
			// Vary seed for each attempt
			currentSeed := (int64(levelID) * 31337) + int64(retry*12345) + int64(len(strat))

			genCfg, err = buildGenerationConfig(levelID, difficulty, batchCfg)
			if err != nil {
				result.Success = false
				result.Error = err.Error()
				return result
			}
			genCfg.Seed = currentSeed
			genCfg.Strategy = strat

			if batchCfg.DryRun {
				result.Success = true
				result.GenerationMS = 0
				result.Coverage = 100.0
				result.BlockingDepth = 2
				common.Info("DRY RUN: Would generate level %d (%s) using %s", levelID, difficulty, strat)
				return result
			}

			// Generate
			level, stats, err = generateLevel(genCfg)

			// Validate
			valid := false
			if err == nil {
				_, valErr := validateGeneratedLevel(level)
				if valErr == nil {
					valid = true
				} else {
					common.Warning("  Validation failed for level %d (%s): %v", levelID, strat, valErr)
				}
			}

			if valid {
				coverage, _ := validateGeneratedLevel(level)
				result.Success = true
				result.Coverage = coverage
				result.BlockingDepth = 2 // TODO: calculate actual blocking depth
				result.GenerationMS = time.Since(startTime).Milliseconds()
				common.Info("  ✓ Level %d generated using %s (Attempt %d)", levelID, strat, retry+1)
				goto success
			}
		}

		common.Warning("  Level %d: Strategy %s failed after %d attempts. Trying next fallback...", levelID, strat, maxRetriesPerStrategy)
	}

	result.Success = false
	result.Error = "failed to generate solvable level after exhausting all strategies"
	return result

success:

	// Optionally write per-level stats JSON to StatsOut directory
	if batchCfg.StatsOut != "" {
		_ = os.MkdirAll(batchCfg.StatsOut, 0o755)
		statsObj := map[string]interface{}{
			"level_id":             levelID,
			"coverage":             result.Coverage,
			"generation_ms":        result.GenerationMS,
			"placement_attempts":   stats.PlacementAttempts,
			"backtracks_attempted": stats.BacktracksAttempted,
			"dumps_produced":       stats.DumpsProduced,
			"max_blocking_depth":   stats.MaxBlockingDepth,
		}
		if stats.BlockingDepthSamples > 0 {
			statsObj["avg_blocking_depth"] = float64(stats.TotalBlockingDepth) / float64(stats.BlockingDepthSamples)
		}
		fname := fmt.Sprintf("%s/level_%d_stats.json", batchCfg.StatsOut, levelID)
		b, _ := json.MarshalIndent(statsObj, "", "  ")
		_ = os.WriteFile(fname, b, 0o644)
		common.Info("Wrote per-level stats: %s", fname)
	}

	common.Info("Generated level %d (%s) - Coverage: %.1f%%, Time: %dms",
		levelID, difficulty, result.Coverage, result.GenerationMS)

	return result
}

func buildGenerationConfig(levelID int, difficulty string, batchCfg Config) (config.GenerationConfig, error) { // Renamed param to avoid collision
	spec, ok := config.DifficultySpecs[difficulty]
	if !ok {
		return config.GenerationConfig{}, fmt.Errorf("unknown difficulty: %s", difficulty)
	}

	gridRange, ok := config.GridSizeRanges[difficulty]
	if !ok {
		return config.GenerationConfig{}, fmt.Errorf("no grid size config for difficulty: %s", difficulty)
	}

	gridWidth := (gridRange.MinW + gridRange.MaxW) / 2
	gridHeight := (gridRange.MinH + gridRange.MaxH) / 2
	if gridWidth < 2 || gridHeight < 2 {
		return config.GenerationConfig{}, fmt.Errorf("invalid grid size computed for %s", difficulty)
	}

	totalCells := gridWidth * gridHeight
	// Enforce 100% coverage for all levels as per Design Doc
	targetCoverage := 1.0
	vineCount := computeVineCount(spec, totalCells, targetCoverage)
	maxMoves := vineCount * 2

	// Default backtracking settings
	backtrackWindow := 3
	maxBackAttempts := 2
	if batchCfg.Aggressive {
		backtrackWindow = 6
		maxBackAttempts = 6
	}

	genCfg := config.GenerationConfig{
		LevelID:              levelID,
		GridWidth:            gridWidth,
		GridHeight:           gridHeight,
		VineCount:            vineCount,
		MaxMoves:             maxMoves,
		OutputFile:           fmt.Sprintf("%s/level_%d.json", batchCfg.OutputDir, levelID),
		Randomize:            false,
		Seed:                 int64(levelID) * 31337,
		Overwrite:            batchCfg.Overwrite,
		MinCoverage:          targetCoverage,
		Difficulty:           difficulty,
		Strategy:             determineStrategy(levelID, difficulty, batchCfg),
		BacktrackWindow:      backtrackWindow,
		MaxBacktrackAttempts: maxBackAttempts,
	}

	// Apply global MinCoverage override if provided (0 = no override)
	if batchCfg.MinCoverage > 0 {
		if batchCfg.MinCoverage < 0.0 || batchCfg.MinCoverage > 1.0 {
			return config.GenerationConfig{}, fmt.Errorf("invalid MinCoverage override: %v", batchCfg.MinCoverage)
		}
		genCfg.MinCoverage = batchCfg.MinCoverage
	} else {
		// Default to 1.0 if no override
		genCfg.MinCoverage = 1.0
	}

	if batchCfg.DumpDir != "" {
		genCfg.DumpDir = batchCfg.DumpDir
	}

	return genCfg, nil
}

func computeVineCount(spec config.DifficultySpec, totalCells int, targetCoverage float64) int {
	avgLength := (spec.AvgLengthRange[0] + spec.AvgLengthRange[1]) / 2
	if avgLength < 2 {
		avgLength = 2
	}

	targetOccupiedCells := int(float64(totalCells) * targetCoverage)
	vineCount := targetOccupiedCells / avgLength

	if vineCount < spec.VineCountRange[0] {
		vineCount = spec.VineCountRange[0]
	}
	if vineCount > spec.VineCountRange[1] {
		vineCount = spec.VineCountRange[1]
	}

	if vineCount > totalCells/4 {
		vineCount = totalCells / 4
	}
	if vineCount < 3 {
		vineCount = 3
	}

	return vineCount
}

func generateLevel(genConfig config.GenerationConfig) (model.Level, config.GenerationStats, error) {
	return generator.GenerateLevel(genConfig)
}

func determineStrategy(levelID int, difficulty string, batchCfg Config) string {
	// If explicit strategy override provided, use it
	if batchCfg.Strategy != "" {
		return batchCfg.Strategy
	}

	// Always use ClearableFirst (optimized) for high coverage >95%
	return config.StrategyLegacyClearable
}

func validateGeneratedLevel(level model.Level) (float64, error) {
	structErrors := validator.ValidateStructural(level)
	if len(structErrors) > 0 {
		for _, e := range structErrors {
			common.Warning("  [STRUCTURAL ERROR] Level %d: %v", level.ID, e)
		}
		return 0, fmt.Errorf("structural validation failed: %d errors", len(structErrors))
	}

	solvable, _, err := validator.IsSolvable(level, 1000000)
	if err != nil {
		return 0, fmt.Errorf("solvability check error: %v", err)
	}

	if !solvable {
		return 0, fmt.Errorf("level not solvable")
	}

	coverage := (float64(level.GetOccupiedCells()) / float64(level.GetTotalCells())) * 100.0
	return coverage, nil
}
