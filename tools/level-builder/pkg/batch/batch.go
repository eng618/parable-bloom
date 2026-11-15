package batch

import (
	"encoding/json"
	"fmt"
	"os"
	"runtime"
	"sync"
	"time"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/config"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/metrics"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/utils"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/ui"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/validator"
)

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
	// Quality instrumentation (populated on success)
	PlayableCoverage float64 `json:"playable_coverage,omitempty"`
	ComplexityScore  float64 `json:"complexity_score,omitempty"`
	AvgVineLength    float64 `json:"avg_vine_length,omitempty"`
	LengthVariety    int     `json:"length_variety,omitempty"`
	DistinctColors   int     `json:"distinct_colors,omitempty"`
	VineCount        int     `json:"vine_count,omitempty"`
}

// MaxModuleID bounds module IDs to two digits, matching the generic logical
// ID scheme lvl_mNN_MM in common.LogicalLevelID (24 modules = 504 levels).
const MaxModuleID = 99

// ModuleBatch represents a complete batch of levels for a module.
type ModuleBatch struct {
	ModuleID     int
	Levels       []Result
	TotalTime    time.Duration
	SuccessCount int
	FailureCount int
}

// GenerateModule generates all 21 levels for a module (5 per tier + 1 Transcendent) concurrently.
// Pattern comes from common.DifficultyForModuleLevel (canonical progression):
// levels 1-5 (Seedling), 6-10 (Sprout), 11-15 (Nurturing), 16-20 (Flourishing), 21 (Transcendent).
// For module N, level IDs start at (N-1)*21+1.
func GenerateModule(batchCfg Config) (*ModuleBatch, error) {
	if batchCfg.ModuleID < 1 || batchCfg.ModuleID > MaxModuleID {
		return nil, fmt.Errorf("invalid module ID: %d (must be 1-%d)", batchCfg.ModuleID, MaxModuleID)
	}

	if batchCfg.OutputDir == "" {
		if levelsDir, err := common.LevelsDir(); err == nil {
			batchCfg.OutputDir = levelsDir
		} else {
			batchCfg.OutputDir = "assets/levels"
		}
	}

	startTime := time.Now()
	batch := &ModuleBatch{
		ModuleID: batchCfg.ModuleID,
		Levels:   []Result{},
	}

	startLevelID := (batchCfg.ModuleID-1)*common.LevelsPerModule + 1

	spin := ui.NewSpinner(fmt.Sprintf("Generating Module %d...", batchCfg.ModuleID))
	spin.Start()
	defer spin.Stop()

	// 1. Gather all levels to generate using the canonical progression.
	// Keeps batch locked to modules.json / validator expectations.
	type levelToGen struct {
		id         int
		difficulty string
	}
	var levelsToGen []levelToGen

	for i := 0; i < common.LevelsPerModule; i++ {
		levelID := startLevelID + i
		difficulty := common.DifficultyForModuleLevel(i)
		// Defensive: difficulty param of GenerateModule is authoritative via
		// progression.go; fail fast if tiers drift from registry.
		levelsToGen = append(levelsToGen, levelToGen{
			id:         levelID,
			difficulty: difficulty,
		})
	}

	// 2. Process levels concurrently using bounded worker pool
	concurrency := runtime.NumCPU()
	if concurrency > len(levelsToGen) {
		concurrency = len(levelsToGen)
	}

	sem := make(chan struct{}, concurrency)
	var wg sync.WaitGroup
	var mu sync.Mutex
	resultsMap := make(map[int]Result)
	completed := 0

	for _, l := range levelsToGen {
		l := l
		wg.Add(1)
		go func() {
			defer wg.Done()
			sem <- struct{}{}
			defer func() { <-sem }()

			mu.Lock()
			spin.UpdateMessage("Generating Level ID %d (%d/21 complete)...", l.id, completed)
			mu.Unlock()

			result := generateSingleLevel(
				l.id,
				l.difficulty,
				batchCfg,
				spin,
			)

			mu.Lock()
			resultsMap[l.id] = result
			completed++
			spin.UpdateMessage("Completed Level ID %d (%d/21 complete)...", l.id, completed)
			mu.Unlock()
		}()
	}

	wg.Wait()

	// 3. Re-order results by Level ID so the batch outputs are perfectly deterministic
	for i := 0; i < common.LevelsPerModule; i++ {
		levelID := startLevelID + i
		result, found := resultsMap[levelID]
		if !found {
			return nil, fmt.Errorf("missing results for level ID %d", levelID)
		}
		batch.Levels = append(batch.Levels, result)
		if result.Success {
			batch.SuccessCount++
		} else {
			batch.FailureCount++
		}
	}

	batch.TotalTime = time.Since(startTime)

	return batch, nil
}

// generateSingleLevel generates a single level and returns results.
func generateSingleLevel(levelID int, difficulty string, batchCfg Config, spin *ui.Spinner) Result {
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

	// Primary motif, then the other placers. A slot that cannot pass the
	// contract still has a solvable fallback. Stats record which one won.
	primary := determineStrategy(levelID, difficulty, batchCfg)
	strategiesToTry = append(strategiesToTry, primary)
	for _, extra := range []string{config.StrategyLegacyClearable, config.StrategyCenterOut, config.StrategyDirectionFirst} {
		if extra != primary {
			strategiesToTry = append(strategiesToTry, extra)
		}
	}

	const maxRetriesPerStrategy = 20

	for _, strat := range strategiesToTry {
		for retry := 0; retry < maxRetriesPerStrategy; retry++ {
			var err error
			// Deterministic seed chain: BaseSeed override wins, else level-derived.
			// Includes retry and strategy length so fallbacks diverge reproducibly.
			baseSeed := int64(levelID) * 31337
			if batchCfg.BaseSeed != 0 {
				baseSeed = batchCfg.BaseSeed + int64(levelID)
			}
			currentSeed := baseSeed + int64(retry*12345) + int64(len(strat))

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
				spin.LogInfo("DRY RUN: Would generate level %d (%s) using %s", levelID, difficulty, strat)
				return result
			}

			// Generate
			level, stats, err = generateLevel(genCfg)
			if err != nil {
				spin.LogWarning("  Placement failed for level %d (%s): %v", levelID, strat, err)
			}

			// Validate (difficulty lock + structural + solvable + coverage + quality)
			valid := false
			var acceptedCoverage float64
			var acceptedQuality metrics.QualityReport
			if err == nil {
				if derr := checkDifficultyLock(levelID, difficulty, level); derr != nil {
					spin.LogWarning("  Difficulty lock failed for level %d: %v", levelID, derr)
				} else if cov, q, valErr := validateGeneratedLevel(level, genCfg.MinCoverage); valErr == nil {
					valid = true
					acceptedCoverage = cov
					acceptedQuality = q
				} else {
					spin.LogWarning("  Validation failed for level %d (%s): %v", levelID, strat, valErr)
				}
			}

			if valid {
				if werr := generator.SaveLevel(level, genCfg); werr != nil {
					spin.LogWarning("  Write failed for level %d (%s): %v", levelID, strat, werr)
					valid = false
				}
			}

			if valid {
				coverage := acceptedCoverage
				quality := acceptedQuality
				result.Success = true
				result.Coverage = coverage
				result.BlockingDepth = quality.BlockingDepth
				result.GenerationMS = time.Since(startTime).Milliseconds()
				result.PlayableCoverage = quality.PlayableCoverage * 100.0
				result.ComplexityScore = quality.ComplexityScore
				result.AvgVineLength = quality.AvgVineLength
				result.LengthVariety = quality.LengthVariety
				result.DistinctColors = quality.DistinctColors
				result.VineCount = len(level.Vines)
				spin.LogInfo("  ✓ Level %d generated using %s (Attempt %d)", levelID, strat, retry+1)
				goto success
			}
		}

		spin.LogWarning("  Level %d: Strategy %s failed after %d attempts. Trying next fallback...", levelID, strat, maxRetriesPerStrategy)
	}

	result.Success = false
	result.Error = "failed to generate solvable level after exhausting all strategies"
	return result

success:

	// Optionally write per-level stats JSON to StatsOut directory
	if batchCfg.StatsOut != "" {
		_ = os.MkdirAll(batchCfg.StatsOut, 0o755)
		wonMotif := genCfg.Motif
		if genCfg.Strategy != primary {
			wonMotif = genCfg.Strategy
		}
		statsObj := map[string]interface{}{
			"level_id":             levelID,
			"difficulty":           difficulty,
			"strategy":             genCfg.Strategy,
			"motif":                wonMotif,
			"requested_motif":      genCfg.Motif,
			"seed":                 genCfg.Seed,
			"grid":                 []int{genCfg.GridWidth, genCfg.GridHeight},
			"coverage":             result.Coverage,
			"playable_coverage":    result.PlayableCoverage,
			"complexity_score":     result.ComplexityScore,
			"avg_vine_length":      result.AvgVineLength,
			"length_variety":       result.LengthVariety,
			"distinct_colors":      result.DistinctColors,
			"vine_count":           result.VineCount,
			"generation_ms":        result.GenerationMS,
			"placement_attempts":   stats.PlacementAttempts,
			"backtracks_attempted": stats.BacktracksAttempted,
			"dumps_produced":       stats.DumpsProduced,
			"max_blocking_depth":   result.BlockingDepth,
		}
		if stats.BlockingDepthSamples > 0 {
			statsObj["avg_blocking_depth"] = float64(stats.TotalBlockingDepth) / float64(stats.BlockingDepthSamples)
		}
		fname := fmt.Sprintf("%s/level_%d_stats.json", batchCfg.StatsOut, levelID)
		b, _ := json.MarshalIndent(statsObj, "", "  ")
		_ = os.WriteFile(fname, b, 0o644)
		spin.LogInfo("Wrote per-level stats: %s", fname)
	}

	spin.LogInfo("Generated level %d (%s) - Coverage: %.1f%%, Time: %dms",
		levelID, difficulty, result.Coverage, result.GenerationMS)

	return result
}

func buildGenerationConfig(levelID int, difficulty string, batchCfg Config) (config.GenerationConfig, error) { // Renamed param to avoid collision
	spec, ok := config.DifficultySpecs[difficulty]
	if !ok {
		return config.GenerationConfig{}, fmt.Errorf("unknown difficulty: %s", difficulty)
	}

	gridWidth, gridHeight := common.ExpectedGrid(levelID)
	if gridWidth < 2 || gridHeight < 2 {
		return config.GenerationConfig{}, fmt.Errorf("invalid grid size computed for %s", difficulty)
	}

	totalCells := gridWidth * gridHeight
	// Placers stop at 97% vine occupancy. The pipeline masks the rest so
	// playable coverage stays 100% without a field of 2-cell fillers.
	targetCoverage := 0.97
	vineCount := computeVineCount(spec, totalCells, targetCoverage)
	maxMoves := vineCount * 2

	// Default backtracking settings
	backtrackWindow := 3
	maxBackAttempts := 2
	if batchCfg.Aggressive {
		backtrackWindow = 6
		maxBackAttempts = 6
	}

	slot := common.SlotInTier(levelID)
	challenge := common.IsChallengeLevel(levelID)
	strategy, motif := utils.MotifForSlot(slot, challenge)
	if chosen := determineStrategy(levelID, difficulty, batchCfg); chosen != "" {
		strategy = chosen
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
		Strategy:             strategy,
		BacktrackWindow:      backtrackWindow,
		MaxBacktrackAttempts: maxBackAttempts,
		Slot:                 slot,
		Motif:                motif,
		Profile:              utils.ProfileForSlot(difficulty, slot, challenge),
		AnchorRatio:          utils.AnchorRatioForSlot(slot, challenge),
	}

	// An explicit override replaces the 97% stop target. Zero keeps it.
	// Do not fall back to 100%: placers treat a miss as a hard abort and
	// the pipeline never gets vines to extend, fill, and mask.
	if batchCfg.MinCoverage > 0 {
		if batchCfg.MinCoverage < 0.0 || batchCfg.MinCoverage > 1.0 {
			return config.GenerationConfig{}, fmt.Errorf("invalid MinCoverage override: %v", batchCfg.MinCoverage)
		}
		genCfg.MinCoverage = batchCfg.MinCoverage
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
	// Validate before writing. GenerateLevel would persist a rejected
	// board and the next seed would stop on "file already exists".
	return generator.GenerateRobust(genConfig)
}

func determineStrategy(levelID int, difficulty string, batchCfg Config) string {
	if batchCfg.Strategy != "" {
		return batchCfg.Strategy
	}
	if batchCfg.UseLIFO {
		return config.StrategyCenterOut
	}
	strategy, _ := utils.MotifForSlot(common.SlotInTier(levelID), common.IsChallengeLevel(levelID))
	return strategy
}

func validateGeneratedLevel(level model.Level, minCoverage float64) (float64, metrics.QualityReport, error) {
	var empty metrics.QualityReport
	structErrors := validator.ValidateStructural(level)
	if len(structErrors) > 0 {
		for _, e := range structErrors {
			common.Warning("  [STRUCTURAL ERROR] Level %d: %v", level.ID, e)
		}
		return 0, empty, fmt.Errorf("structural validation failed: %d errors", len(structErrors))
	}

	solvable, _, err := validator.IsSolvable(level, 1000000)
	if err != nil {
		return 0, empty, fmt.Errorf("solvability check error: %v", err)
	}

	if !solvable {
		return 0, empty, fmt.Errorf("level not solvable")
	}

	quality := metrics.AnalyzeQuality(level)
	coverage := (float64(level.GetOccupiedCells()) / float64(level.GetTotalCells())) * 100.0
	// Enforce coverage threshold (fraction 0-1).
	// Semantics: playable coverage (vine cells + masked cells) must reach minCoverage.
	// Vine occupancy alone may be lower (e.g. 95% vines + 5% mask = 100% playable).
	if minCoverage > 0 {
		if quality.PlayableCoverage+1e-9 < minCoverage {
			return coverage, quality, fmt.Errorf("playable coverage %.1f%% below minimum %.1f%%", quality.PlayableCoverage*100, minCoverage*100)
		}
		// Full playability: every non-vine cell must be masked.
		if errs := validator.ValidateDesignConstraints(level); len(errs) > 0 {
			return coverage, quality, fmt.Errorf("design constraints failed: %v", errs[0])
		}
	}
	if qerr := checkQuality(level, quality); qerr != nil {
		return coverage, quality, qerr
	}
	return coverage, quality, nil
}

// checkDifficultyLock ensures the generated level's difficulty matches the
// canonical progression for its ID (prevents tier shuffle in future batches).
func checkDifficultyLock(levelID int, expectedDifficulty string, level model.Level) error {
	canonical := common.ExpectedDifficulty(levelID)
	if expectedDifficulty != canonical {
		return fmt.Errorf("requested difficulty %s disagrees with canonical %s for level %d", expectedDifficulty, canonical, levelID)
	}
	if level.Difficulty != "" && level.Difficulty != canonical {
		return fmt.Errorf("generated difficulty %s mismatches canonical %s for level %d", level.Difficulty, canonical, levelID)
	}
	return nil
}

// checkQuality applies the new-ladder contract. Blocking depth stays telemetry:
// the recorded chain does not match DifficultySpecs.MaxBlockingDepth.
func checkQuality(level model.Level, q metrics.QualityReport) error {
	return metrics.CheckContract(level, q)
}
