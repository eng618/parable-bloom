package batch

import (
	"encoding/json"
	"fmt"
	"os"
	"time"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/gen2"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator"
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
	Specs generator.DifficultySpec
}

// getDifficultyTiers returns the 4 non-transcendent difficulty tiers in order.
func getDifficultyTiers() []difficultyTier {
	return []difficultyTier{
		{Index: 0, Name: "Seedling", Specs: generator.DifficultySpecs["Seedling"]},
		{Index: 1, Name: "Sprout", Specs: generator.DifficultySpecs["Sprout"]},
		{Index: 2, Name: "Nurturing", Specs: generator.DifficultySpecs["Nurturing"]},
		{Index: 3, Name: "Flourishing", Specs: generator.DifficultySpecs["Flourishing"]},
	}
}

// GenerateModule generates all 21 levels for a module (5 per tier + 1 Transcendent).
// Pattern: levels 1-5 (Seedling), 6-10 (Sprout), 11-15 (Nurturing), 16-20 (Flourishing), 21 (Transcendent).
// For module N, level IDs start at (N-1)*21+1.
func GenerateModule(config Config) (*ModuleBatch, error) {
	if config.ModuleID < 1 || config.ModuleID > 5 {
		return nil, fmt.Errorf("invalid module ID: %d (must be 1-5)", config.ModuleID)
	}

	if config.OutputDir == "" {
		config.OutputDir = "assets/levels"
	}

	startTime := time.Now()
	batch := &ModuleBatch{
		ModuleID: config.ModuleID,
		Levels:   []Result{},
	}

	startLevelID := (config.ModuleID-1)*21 + 1

	tiers := getDifficultyTiers()
	for tierIdx, tier := range tiers {
		for levelInTier := 0; levelInTier < 5; levelInTier++ {
			levelID := startLevelID + tierIdx*5 + levelInTier
			result := generateSingleLevel(
				levelID,
				tier.Name,
				config,
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
		config,
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
func generateSingleLevel(levelID int, difficulty string, config Config) Result {
	result := Result{
		LevelID:    levelID,
		Difficulty: difficulty,
	}

	startTime := time.Now()

	var level model.Level
	var stats gen2.GenerationStats
	var genCfg gen2.GenerationConfig

	// Strategy Chain:
	// 1. Requested Strategy (from config or auto-determined)
	// 2. Center-Out (LIFO) - strongest solvability guarantee
	// 3. Direction-First - backup for organic shapes
	
	strategiesToTry := []string{}
	
	// Determine primary strategy
	primary := determineStrategy(levelID, difficulty, config)
	strategiesToTry = append(strategiesToTry, primary)

	// Add fallbacks if they aren't the primary
	if primary != gen2.StrategyCenterOut {
		strategiesToTry = append(strategiesToTry, gen2.StrategyCenterOut)
	}
	if primary != gen2.StrategyDirectionFirst && primary != gen2.StrategyCenterOut {
		// Only add DirectionFirst if it wasn't already tried
		strategiesToTry = append(strategiesToTry, gen2.StrategyDirectionFirst)
	}

	const maxRetriesPerStrategy = 5

	for _, strat := range strategiesToTry {
		for retry := 0; retry < maxRetriesPerStrategy; retry++ {
			var err error
			// Vary seed for each attempt
			currentSeed := (int64(levelID) * 31337) + int64(retry*12345) + int64(len(strat))
			
			genCfg, err = buildGenerationConfig(levelID, difficulty, config)
			if err != nil {
				result.Success = false
				result.Error = err.Error()
				return result
			}
			genCfg.Seed = currentSeed
			genCfg.Strategy = strat

			if config.DryRun {
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
					// common.Warning("  Validation failed for level %d (%s): %v", levelID, strat, valErr)
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
	if config.StatsOut != "" {
		_ = os.MkdirAll(config.StatsOut, 0o755)
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
		fname := fmt.Sprintf("%s/level_%d_stats.json", config.StatsOut, levelID)
		b, _ := json.MarshalIndent(statsObj, "", "  ")
		_ = os.WriteFile(fname, b, 0o644)
		common.Info("Wrote per-level stats: %s", fname)
	}

	common.Info("Generated level %d (%s) - Coverage: %.1f%%, Time: %dms",
		levelID, difficulty, result.Coverage, result.GenerationMS)

	return result
}

func buildGenerationConfig(levelID int, difficulty string, config Config) (gen2.GenerationConfig, error) {
	spec, ok := generator.DifficultySpecs[difficulty]
	if !ok {
		return gen2.GenerationConfig{}, fmt.Errorf("unknown difficulty: %s", difficulty)
	}

	gridRange, ok := generator.GridSizeRanges[difficulty]
	if !ok {
		return gen2.GenerationConfig{}, fmt.Errorf("no grid size config for difficulty: %s", difficulty)
	}

	gridWidth := (gridRange.MinW + gridRange.MaxW) / 2
	gridHeight := (gridRange.MinH + gridRange.MaxH) / 2
	if gridWidth < 2 || gridHeight < 2 {
		return gen2.GenerationConfig{}, fmt.Errorf("invalid grid size computed for %s", difficulty)
	}

	totalCells := gridWidth * gridHeight
	// Enforce 100% coverage for all levels as per Design Doc
	targetCoverage := 1.0
	vineCount := computeVineCount(spec, totalCells, targetCoverage)
	maxMoves := vineCount * 2

	// Default backtracking settings
	backtrackWindow := 3
	maxBackAttempts := 2
	if config.Aggressive {
		backtrackWindow = 6
		maxBackAttempts = 6
	}

	genCfg := gen2.GenerationConfig{
		LevelID:              levelID,
		GridWidth:            gridWidth,
		GridHeight:           gridHeight,
		VineCount:            vineCount,
		MaxMoves:             maxMoves,
		OutputFile:           fmt.Sprintf("%s/level_%d.json", config.OutputDir, levelID),
		Randomize:            false,
		Seed:                 int64(levelID) * 31337,
		Overwrite:            config.Overwrite,
		MinCoverage:          targetCoverage,
		Difficulty:           difficulty,
		Strategy:             determineStrategy(levelID, difficulty, config),
		BacktrackWindow:      backtrackWindow,
		MaxBacktrackAttempts: maxBackAttempts,
	}

	// Apply global MinCoverage override if provided (0 = no override)
	if config.MinCoverage > 0 {
		if config.MinCoverage < 0.0 || config.MinCoverage > 1.0 {
			return gen2.GenerationConfig{}, fmt.Errorf("invalid MinCoverage override: %v", config.MinCoverage)
		}
		genCfg.MinCoverage = config.MinCoverage
	} else {
		// Default to 1.0 if no override
		genCfg.MinCoverage = 1.0
	}

	if config.DumpDir != "" {
		genCfg.DumpDir = config.DumpDir
	}

	return genCfg, nil
}

func computeVineCount(spec generator.DifficultySpec, totalCells int, targetCoverage float64) int {
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

func generateLevel(genConfig gen2.GenerationConfig) (model.Level, gen2.GenerationStats, error) {
	return gen2.GenerateLevel(genConfig)
}

func determineStrategy(levelID int, difficulty string, config Config) string {
	// If explicit strategy override provided, use it
	if config.Strategy != "" {
		return config.Strategy
	}

	// Always use LIFO for Transcendent
	if difficulty == "Transcendent" {
		return gen2.StrategyCenterOut
	}

	// For other levels, introduce variety
	// Use levelID + moduleID to make it deterministic but varied
	seed := int64(levelID + config.ModuleID)
	r := (seed % 10) // 0-9

	switch difficulty {
	case "Seedling", "Sprout":
		// 80% Direction-First, 20% Center-Out
		if r < 8 {
			return gen2.StrategyDirectionFirst
		}
		return gen2.StrategyCenterOut
	case "Nurturing", "Flourishing":
		// 60% Direction-First, 40% Center-Out
		if r < 6 {
			return gen2.StrategyDirectionFirst
		}
		return gen2.StrategyCenterOut
	default:
		return gen2.StrategyDirectionFirst
	}
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
