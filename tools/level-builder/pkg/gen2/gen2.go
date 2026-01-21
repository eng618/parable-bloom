package gen2

import (
	crand "crypto/rand"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"math/rand"
	"os"
	"path/filepath"
	"time"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/validator"
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
}

// GenerationStats tracks performance and quality metrics
type GenerationStats struct {
	PlacementAttempts int
	SolvabilityChecks validator.SolvabilityStats
	MaxBlockingDepth  int
	GridCoverage      float64
	GenerationTime    time.Duration
}

// VinePlacementStrategy defines the interface for vine placement algorithms
type VinePlacementStrategy interface {
	PlaceVines(config GenerationConfig, rng *rand.Rand) ([]model.Vine, map[string]string, error)
}

// BlockingAnalyzer defines the interface for blocking relationship analysis
type BlockingAnalyzer interface {
	AnalyzeBlocking(vines []model.Vine, occupied map[string]string) (BlockingAnalysis, error)
}

// BlockingAnalysis contains blocking relationship data
type BlockingAnalysis struct {
	MaxDepth       int
	HasCircular    bool
	CircularChains [][]string
}

// Assembler defines the interface for assembling final level data
type Assembler interface {
	AssembleLevel(config GenerationConfig, vines []model.Vine, mask *model.Mask, seed int64) model.Level
}

// generationState holds the mutable state during level generation
type generationState struct {
	vines    []model.Vine
	occupied map[string]string
	analysis BlockingAnalysis
	solvable bool
	stats    validator.SolvabilityStats
}

// initializeRNG creates the random number generator from config
func initializeRNG(config GenerationConfig) (*rand.Rand, int64) {
	var seed int64
	if config.Randomize {
		seed = cryptoSeedInt64()
	} else if config.Seed != 0 {
		seed = config.Seed
	} else {
		seed = int64(config.LevelID * 31337)
	}
	common.Verbose("Using seed: %d", seed)
	return rand.New(rand.NewSource(seed)), seed
}

// attemptGeneration performs a single generation attempt with optional backtracking
func attemptGeneration(
	config GenerationConfig,
	placer *DirectionFirstPlacer,
	analyzer *DFSBlockingAnalyzer,
	rng *rand.Rand,
	maxBacktrack int,
) *generationState {
	vines, occupied, err := placer.PlaceVines(config, rng)
	if err != nil {
		common.Verbose("Placement failed: %v", err)
		return nil
	}

	analysis, err := analyzer.AnalyzeBlocking(vines, occupied)
	if err != nil {
		common.Verbose("Blocking analysis failed: %v", err)
		return nil
	}

	state := &generationState{vines: vines, occupied: occupied, analysis: analysis}

	if analysis.HasCircular {
		common.Verbose("Circular blocking detected, backtracking...")
		state.vines, state.occupied = backtrackVines(vines, occupied, maxBacktrack)
		state.analysis, _ = analyzer.AnalyzeBlocking(state.vines, state.occupied)
		if state.analysis.HasCircular {
			return nil
		}
	}

	state.solvable, state.stats = checkSolvability(config, state.vines)
	if state.solvable {
		return state
	}

	// Backtrack and retry
	state.vines, state.occupied = backtrackVines(state.vines, state.occupied, maxBacktrack)
	state.solvable, state.stats = checkSolvability(config, state.vines)
	if state.solvable && len(state.vines) >= 2 {
		return state
	}
	return nil
}

// finalizeLevelGeneration assembles the level and writes it to file
func finalizeLevelGeneration(
	config GenerationConfig,
	state *generationState,
	assembler *LevelAssembler,
	seed int64,
	stats *GenerationStats,
	startTime time.Time,
) (model.Level, error) {
	coverage := calculateGridCoverage(config, state.occupied)
	stats.GridCoverage = coverage

	var mask *model.Mask
	if coverage < 1.0 {
		emptyCells := findEmptyCells(config, state.occupied)
		if len(emptyCells) > 0 {
			mode := "hide"
			if len(emptyCells) <= config.GridWidth*config.GridHeight/100 {
				mode = "show-all"
			}
			mask = &model.Mask{Mode: mode, Points: emptyCells}
		}
	}

	level := assembler.AssembleLevel(config, state.vines, mask, seed)

	if err := writeLevelToFile(level, config); err != nil {
		return model.Level{}, fmt.Errorf("failed to write level file: %w", err)
	}

	stats.GenerationTime = time.Since(startTime)
	return level, nil
}

// runGenerationAttempts runs the generation loop until a solvable level is found
func runGenerationAttempts(
	config GenerationConfig,
	placer *DirectionFirstPlacer,
	analyzer *DFSBlockingAnalyzer,
	rng *rand.Rand,
	seed int64,
	maxAttempts, maxBacktrack int,
) *generationState {
	for attempt := 1; attempt <= maxAttempts; attempt++ {
		common.Verbose("Generation attempt %d/%d", attempt, maxAttempts)

		attemptRng := rng
		if attempt > 1 {
			attemptRng = rand.New(rand.NewSource(seed + int64(attempt*10000)))
		}

		state := attemptGeneration(config, placer, analyzer, attemptRng, maxBacktrack)
		if state != nil && state.solvable {
			common.Verbose("Found solvable level on attempt %d with %d vines", attempt, len(state.vines))
			return state
		}
	}
	return nil
}

// attemptLIFOGeneration performs generation using center-out placer with LIFO guarantee
// No expensive solvability checks needed since LIFO ordering is guaranteed by construction
func attemptLIFOGeneration(
	config GenerationConfig,
	placer *CenterOutPlacer,
	analyzer *DFSBlockingAnalyzer,
	rng *rand.Rand,
) *generationState {
	vines, occupied, err := placer.PlaceVines(config, rng)
	if err != nil {
		common.Verbose("LIFO placement failed: %v", err)
		return nil
	}

	analysis, err := analyzer.AnalyzeBlocking(vines, occupied)
	if err != nil {
		common.Verbose("Blocking analysis failed: %v", err)
		return nil
	}

	// Check coverage - if we added non-LIFO fillers, we need to verify solvability
	coverage := float64(len(occupied)) / float64(config.GridWidth*config.GridHeight)
	if coverage >= 0.90 {
		// High coverage likely includes non-LIFO fillers, verify solvability
		solvable, stats := checkSolvability(config, vines)
		if !solvable {
			common.Verbose("High-coverage LIFO level not solvable, rejecting")
			return nil
		}
		return &generationState{
			vines:    vines,
			occupied: occupied,
			analysis: analysis,
			solvable: true,
			stats:    stats,
		}
	}

	// Lower coverage - pure LIFO vines, guaranteed solvable
	return &generationState{
		vines:    vines,
		occupied: occupied,
		analysis: analysis,
		solvable: true, // Guaranteed by LIFO construction
	}
}

// runLIFOAttempts runs multiple LIFO generation attempts until success
func runLIFOAttempts(
	config GenerationConfig,
	placer *CenterOutPlacer,
	analyzer *DFSBlockingAnalyzer,
	rng *rand.Rand,
	seed int64,
	maxAttempts int,
) *generationState {
	for attempt := 1; attempt <= maxAttempts; attempt++ {
		common.Verbose("LIFO generation attempt %d/%d", attempt, maxAttempts)

		attemptRng := rng
		if attempt > 1 {
			attemptRng = rand.New(rand.NewSource(seed + int64(attempt*10000)))
		}

		state := attemptLIFOGeneration(config, placer, analyzer, attemptRng)
		if state != nil && len(state.vines) >= 2 {
			common.Verbose("LIFO placement succeeded on attempt %d with %d vines", attempt, len(state.vines))
			return state
		}
	}
	return nil
}

// GenerateLevelLIFO generates a level using center-out placement with LIFO solvability guarantee.
// This is faster than GenerateLevel because it doesn't need expensive A* solver checks.
func GenerateLevelLIFO(config GenerationConfig) (model.Level, GenerationStats, error) {
	startTime := time.Now()
	rng, seed := initializeRNG(config)

	placer := &CenterOutPlacer{}
	analyzer := &DFSBlockingAnalyzer{}
	assembler := &LevelAssembler{}
	stats := GenerationStats{}

	const maxAttempts = 10
	state := runLIFOAttempts(config, placer, analyzer, rng, seed, maxAttempts)

	stats.PlacementAttempts = maxAttempts
	if state != nil {
		stats.MaxBlockingDepth = state.analysis.MaxDepth
	}

	if state == nil || len(state.vines) < 2 {
		return model.Level{}, stats, fmt.Errorf("LIFO generation failed after %d attempts", maxAttempts)
	}

	level, err := finalizeLevelGeneration(config, state, assembler, seed, &stats, startTime)
	if err != nil {
		return model.Level{}, stats, err
	}

	return level, stats, nil
}

// validateGenerationState checks if the generation state is valid for level creation
func validateGenerationState(state *generationState, maxAttempts int) error {
	if state == nil {
		return fmt.Errorf("failed to generate level after %d attempts", maxAttempts)
	}
	if state.analysis.HasCircular {
		return fmt.Errorf("failed to generate level without circular blocking after %d attempts", maxAttempts)
	}
	if !state.solvable {
		return fmt.Errorf("failed to generate solvable level after %d attempts", maxAttempts)
	}
	return nil
}

// GenerateLevel generates a single level using advanced algorithms with
// incremental solvability checking, backtracking, and smart circuit breaking.
func GenerateLevel(config GenerationConfig) (model.Level, GenerationStats, error) {
	startTime := time.Now()
	rng, seed := initializeRNG(config)

	// Create helper components
	placer := &DirectionFirstPlacer{}
	analyzer := &DFSBlockingAnalyzer{}
	assembler := &LevelAssembler{}

	stats := GenerationStats{}

	// Circuit breaker configuration
	const (
		maxAttempts         = 20000 // High retry count for difficult seeds
		baseTimeout         = 60 * time.Second
		extendedTimeout     = 120 * time.Second
		hardTimeout         = 180 * time.Second
		progressLogInterval = 500
	)

	// Adaptive strategy state
	originalMinCoverage := config.MinCoverage
	originalVineCount := config.VineCount

	// Counters for circuit breaker
	structuralSuccessCount := 0
	totalFailures := 0

	// State for smart timeout extension
	timeoutExtended := false

	common.Verbose("Generating Level %d (%s) | Grid: %dx%d | Vines: %d | Target Coverage: %.1f%%",
		config.LevelID, config.Difficulty, config.GridWidth, config.GridHeight, config.VineCount, config.MinCoverage*100)

	for attempt := 1; attempt <= maxAttempts; attempt++ {
		elapsed := time.Since(startTime)

		// 1. SMART CIRCUIT BREAKER CHECK
		timeoutLimit := baseTimeout
		if timeoutExtended {
			timeoutLimit = extendedTimeout
		}

		if elapsed > hardTimeout {
			return model.Level{}, stats, fmt.Errorf("hard timeout reached after %.1fs (%d attempts)", elapsed.Seconds(), attempt)
		}

		if elapsed > timeoutLimit {
			// Check if we should extend timeout based on structural success rate
			// If >5% of attempts produce valid geometry (but fail solvability), the generator is healthy but unlucky.
			structuralRate := float64(structuralSuccessCount) / float64(attempt)
			if !timeoutExtended && structuralRate > 0.05 {
				common.Info("⏱️  Extending timeout: Structural success rate %.1f%% is healthy. Continuing...", structuralRate*100)
				timeoutExtended = true
			} else {
				return model.Level{}, stats, fmt.Errorf("timeout reached after %.1fs (%d attempts, structural_rate=%.1f%%)",
					elapsed.Seconds(), attempt, structuralRate*100)
			}
		}

		// 2. ADAPTIVE STRATEGY
		// Prioritize other tweaks before reducing coverage (Occupancy)
		switch attempt {
		case 500:
			// First relaxation: Try slightly fewer vines (easier to pack)
			newCount := int(float64(originalVineCount) * 0.9)
			if newCount < 3 {
				newCount = 3
			}
			if newCount != config.VineCount {
				config.VineCount = newCount
				common.Verbose("⚠️  Relaxation 1: Reduced vine count to %d (keep coverage high)", config.VineCount)
			}
		case 1500:
			// Second relaxation: Slight coverage reduction if really stuck
			config.MinCoverage = originalMinCoverage - 0.02
			common.Verbose("⚠️  Relaxation 2: Slightly reduced coverage target to %.1f%%", config.MinCoverage*100)
		case 3000:
			// Third relaxation: Further coverage reduction
			config.MinCoverage = originalMinCoverage - 0.05
			common.Verbose("⚠️  Relaxation 3: Reduced coverage target to %.1f%%", config.MinCoverage*100)
		}

		// 3. GENERATION ATTEMPT
		attemptRng := rng
		if attempt > 1 {
			// Diversify RNG for retries
			attemptRng = rand.New(rand.NewSource(seed + int64(attempt*10000)))
		}

		// We use maxBacktrack=3 by default
		state := attemptGeneration(config, placer, analyzer, attemptRng, 3)

		stats.PlacementAttempts++

		// 4. ANALYZE RESULT
		if state != nil {
			// We have valid geometry (vines placed, no circular blocking)
			// Solvability check was done inside attemptGeneration and passed if state != nil
			structuralSuccessCount++

			// Final assembly check
			if err := validateGenerationState(state, attempt); err == nil {
				// We have a winner!
				level, err := finalizeLevelGeneration(config, state, assembler, seed, &stats, startTime)
				if err == nil {
					common.Info("✓ Success on attempt %d (%.2fs)", attempt, time.Since(startTime).Seconds())
					return level, stats, nil
				}
			}
		} else {
			// Failed somewhere
			totalFailures++
		}

		// Periodic progress log
		if attempt > 0 && attempt%progressLogInterval == 0 {
			structuralRate := float64(structuralSuccessCount) / float64(attempt) * 100
			common.Verbose("   Progress: %d/%d (%.1fs) | Struct Rate: %.1f%% | Current Coverage Target: %.1f%%",
				attempt, maxAttempts, time.Since(startTime).Seconds(), structuralRate, config.MinCoverage*100)
		}
	}

	stats.PlacementAttempts = maxAttempts
	return model.Level{}, stats, fmt.Errorf("failed to generate solvable level after %d attempts", maxAttempts)
}

// backtrackVines removes the last N vines and returns updated collections
func backtrackVines(vines []model.Vine, occupied map[string]string, count int) ([]model.Vine, map[string]string) {
	if count >= len(vines) {
		count = len(vines) - 1 // Keep at least one vine
	}
	if count < 1 || len(vines) < 2 {
		return vines, occupied
	}

	// Remove last 'count' vines
	toRemove := vines[len(vines)-count:]
	vines = vines[:len(vines)-count]

	// Remove their cells from occupied
	for _, vine := range toRemove {
		for _, pt := range vine.OrderedPath {
			key := fmt.Sprintf("%d,%d", pt.X, pt.Y)
			delete(occupied, key)
		}
	}

	return vines, occupied
}

// cryptoSeedInt64 returns a crypto-random int64 seed
func cryptoSeedInt64() int64 {
	var b [8]byte
	if _, err := crand.Read(b[:]); err != nil {
		return time.Now().UnixNano()
	}
	return int64(binary.LittleEndian.Uint64(b[:]))
}

// checkSolvability performs solvability check using the validator
func checkSolvability(config GenerationConfig, vines []model.Vine) (bool, validator.SolvabilityStats) {
	// Convert to model.Level for validator
	level := model.Level{
		ID:         config.LevelID,
		GridSize:   []int{config.GridWidth, config.GridHeight},
		Vines:      convertVinesToModel(vines),
		MaxMoves:   config.MaxMoves,
		Grace:      4, // Transcendent gets 4 grace
		Difficulty: "Transcendent",
	}

	solvable, stats, err := validator.IsSolvable(level, 100000) // 100k max states for transcendent
	if err != nil {
		common.Verbose("Solvability check error: %v", err)
		return false, validator.SolvabilityStats{}
	}

	return solvable, stats
}

// calculateGridCoverage calculates what percentage of the grid is occupied
func calculateGridCoverage(config GenerationConfig, occupied map[string]string) float64 {
	totalCells := config.GridWidth * config.GridHeight
	occupiedCells := len(occupied)
	return float64(occupiedCells) / float64(totalCells)
}

// findEmptyCells returns list of empty cell coordinates
func findEmptyCells(config GenerationConfig, occupied map[string]string) []model.Point {
	var empty []model.Point
	for y := 0; y < config.GridHeight; y++ {
		for x := 0; x < config.GridWidth; x++ {
			key := fmt.Sprintf("%d,%d", x, y)
			if _, isOccupied := occupied[key]; !isOccupied {
				empty = append(empty, model.Point{X: x, Y: y})
			}
		}
	}
	return empty
}

// convertVinesToModel converts model.Vine to model.Vine
func convertVinesToModel(vines []model.Vine) []model.Vine {
	result := make([]model.Vine, len(vines))
	for i, v := range vines {
		result[i] = model.Vine{
			ID:            v.ID,
			HeadDirection: v.HeadDirection,
			OrderedPath:   convertCommonPointsToModel(v.OrderedPath),
		}
	}
	return result
}

// writeLevelToFile writes the level to JSON file
func writeLevelToFile(level model.Level, config GenerationConfig) error {
	outputPath := config.OutputFile
	if outputPath == "" {
		outputPath = fmt.Sprintf("../../assets/levels/level_%d.json", config.LevelID)
	}

	// Check if file exists and overwrite is not enabled
	if !config.Overwrite {
		if _, err := os.Stat(outputPath); err == nil {
			return fmt.Errorf("file already exists: %s (use --overwrite to replace)", outputPath)
		}
	}

	// Ensure directory exists
	dir := filepath.Dir(outputPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return fmt.Errorf("failed to create directory: %w", err)
	}

	// Write JSON
	file, err := os.Create(outputPath)
	if err != nil {
		return fmt.Errorf("failed to create file: %w", err)
	}
	defer file.Close()

	encoder := json.NewEncoder(file)
	encoder.SetIndent("", "  ")
	if err := encoder.Encode(level); err != nil {
		return fmt.Errorf("failed to encode JSON: %w", err)
	}

	return nil
}
