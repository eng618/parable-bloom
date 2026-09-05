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
	if batchCfg.ModuleID < 1 || batchCfg.ModuleID > 5 {
		return nil, fmt.Errorf("invalid module ID: %d (must be 1-5)", batchCfg.ModuleID)
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
		statsObj := map[string]interface{}{
			"level_id":             levelID,
			"difficulty":           difficulty,
			"strategy":             genCfg.Strategy,
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

	// Honor LIFO request (center-out has strongest solvability guarantee)
	if batchCfg.UseLIFO || difficulty == "Transcendent" {
		return config.StrategyCenterOut
	}

	// Default: optimized clearable-first for high coverage >95%
	return config.StrategyLegacyClearable
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

// checkQuality rejects degenerate output: monochrome when multi-color expected,
// flat vine lengths, or vine counts outside the difficulty spec.
func checkQuality(level model.Level, q metrics.QualityReport) error {
	spec, ok := config.DifficultySpecs[level.Difficulty]
	if !ok {
		return nil
	}
	if len(level.Vines) < spec.VineCountRange[0] || len(level.Vines) > spec.VineCountRange[1] {
		return fmt.Errorf("vine count %d outside spec range %v for %s", len(level.Vines), spec.VineCountRange, level.Difficulty)
	}
	if spec.ColorCountRange[1] > 1 && q.DistinctColors < 2 && len(level.Vines) >= 4 {
		return fmt.Errorf("degenerate palette: only %d distinct color(s) for %s (expected >1)", q.DistinctColors, level.Difficulty)
	}
	if len(level.Vines) >= 6 && q.LengthVariety < 2 {
		return fmt.Errorf("degenerate shapes: length variety %d (min %d, max %d) for %s", q.LengthVariety, q.MinVineLength, q.MaxVineLength, level.Difficulty)
	}
	// Note: q.BlockingDepth is recorded as telemetry only (see stats JSON).
	// First-step blocking chains measure 1-8 on the current 105-level corpus
	// (Seedling avg ~3.2, Transcendent avg ~5.2) while DifficultySpecs caps read
	// 0-4 under a different notion of depth, so enforcing spec caps here would
	// reject healthy generator output. Revisit once solver-search depth (not
	// first-step chains) is the metric.
	return nil
}
