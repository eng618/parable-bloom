package generator

import (
	"encoding/json"
	"fmt"
	"math/rand"
	"os"
	"path/filepath"
	"time"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/config"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/strategies"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/utils"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/validator"
)

// LegacyBatchConfig holds configuration for batch level generation (legacy)
type LegacyBatchConfig struct {
	Count         int
	BaseSeed      int64
	UseRandomSeed bool
	ModuleID      int
	Difficulty    string
	WorkingDir    string
	Overwrite     bool
}

// Clean removes generated level and module files used by the level builder.
func Clean() error {
	levelsDir, err := common.LevelsDir()
	if err != nil {
		return fmt.Errorf("failed to resolve levels directory: %w", err)
	}

	files, err := filepath.Glob(filepath.Join(levelsDir, "level_*.json"))
	if err != nil {
		return err
	}
	for _, f := range files {
		if err := os.Remove(f); err != nil && !os.IsNotExist(err) {
			return fmt.Errorf("failed to remove %s: %w", f, err)
		}
	}

	modulesFile, err := common.ModulesFile()
	if err != nil {
		return fmt.Errorf("failed to resolve modules.json path: %w", err)
	}

	if err := os.Remove(modulesFile); err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("failed to remove %s: %w", modulesFile, err)
	}
	return nil
}

// Generate creates count levels with the given configuration.
// This is the main entry point called from the generate command.
func Generate(count int, baseSeed int64, useRandomSeed bool, moduleID int, difficulty string, overwrite bool) error {
	cwd, _ := os.Getwd()
	common.Verbose("Generating %d levels (CWD: %s)...", count, cwd)

	levelsDir, err := common.LevelsDir()
	if err != nil {
		return fmt.Errorf("failed to resolve levels directory: %w", err)
	}

	dataDir, err := common.DataDir()
	if err != nil {
		return fmt.Errorf("failed to resolve data directory: %w", err)
	}

	// Ensure output directories exist
	if err := os.MkdirAll(levelsDir, 0o755); err != nil {
		return err
	}
	if err := os.MkdirAll(dataDir, 0o755); err != nil {
		return err
	}

	cfg := LegacyBatchConfig{
		Count:         count,
		BaseSeed:      baseSeed,
		UseRandomSeed: useRandomSeed,
		ModuleID:      moduleID,
		Difficulty:    difficulty,
		WorkingDir:    cwd,
		Overwrite:     overwrite,
	}

	// If module ID is specified, generate entire module
	if moduleID > 0 {
		return generateModule(cfg)
	}

	// Otherwise, generate individual levels
	return generateLevels(cfg)
}

// generateLevels generates a series of individual levels.
func generateLevels(cfg LegacyBatchConfig) error {
	levelsDir, err := common.LevelsDir()
	if err != nil {
		return fmt.Errorf("failed to resolve levels directory: %w", err)
	}

	// Determine the starting level ID
	startID := 1
	existingLevels, err := common.ReadLevelsFromDir(levelsDir)
	if err == nil && len(existingLevels) > 0 {
		maxID := 0
		for _, lvl := range existingLevels {
			if lvl.ID > maxID {
				maxID = lvl.ID
			}
		}
		startID = maxID + 1
		common.Verbose("Found existing levels, starting from ID %d", startID)
	}

	// Generate levels
	for i := 0; i < cfg.Count; i++ {
		levelID := startID + i
		var levelSeed int64
		if cfg.UseRandomSeed {
			levelSeed = cryptoSeedInt64() + int64(i)
		} else if cfg.BaseSeed != 0 {
			levelSeed = cfg.BaseSeed + int64(i)
		} else {
			levelSeed = int64(levelID) * 31337
		}
		rng := rand.New(rand.NewSource(levelSeed))
		var difficultyTier string
		if cfg.Difficulty != "" {
			difficultyTier = cfg.Difficulty
		} else {
			difficultyTier = common.DifficultyForLevel(levelID)
		}
		// Per-level retry logic
		var level model.Level
		var lastErr error
		maxRetries := 5
		for attempt := 1; attempt <= maxRetries; attempt++ {
			level, lastErr = generateSingleLevel(levelID, difficultyTier, levelSeed+int64(attempt)*7919, rng)
			if lastErr == nil {
				break
			}
			// Log error for this attempt
			common.Verbose("[Level %d Attempt %d/%d] Generation failed: %v", levelID, attempt, maxRetries, lastErr)
		}
		if lastErr != nil {
			common.Error("Level %d failed after %d attempts: %v", levelID, maxRetries, lastErr)
			continue // Skip this level, continue batch
		}

		levelsDir, err := common.LevelsDir()
		if err != nil {
			common.Error("Failed to resolve levels directory for level %d: %v", levelID, err)
			continue
		}

		filePath := filepath.Join(levelsDir, fmt.Sprintf("level_%d.json", levelID))
		if err := common.WriteLevel(filePath, &level, cfg.Overwrite); err != nil {
			common.Error("Failed to write level %d: %v", levelID, err)
			continue
		}
		if (i+1)%10 == 0 || (i+1) == cfg.Count {
			common.Info("Generated %d/%d levels...", i+1, cfg.Count)
		}
	}

	common.Info("Successfully generated %d levels", cfg.Count)
	return nil
}

// generateModule generates a complete module with balanced difficulty progression.
// Each module has 21 levels: 20 regular levels (5 each of Seedling, Sprout, Nurturing, Flourishing)
// plus 1 Transcendent boss level at the end.
func generateModule(cfg LegacyBatchConfig) error {
	const levelsPerModule = 21
	const regularLevels = 20

	// Difficulty progression for regular levels (20 levels)
	// 5 Seedling, 5 Sprout, 5 Nurturing, 5 Flourishing, then 1 Transcendent
	difficultyProgression := []string{
		// Levels 1-5: Seedling
		"Seedling", "Seedling", "Seedling", "Seedling", "Seedling",
		// Levels 6-10: Sprout
		"Sprout", "Sprout", "Sprout", "Sprout", "Sprout",
		// Levels 11-15: Nurturing
		"Nurturing", "Nurturing", "Nurturing", "Nurturing", "Nurturing",
		// Levels 16-20: Flourishing
		"Flourishing", "Flourishing", "Flourishing", "Flourishing", "Flourishing",
		// Level 21: Transcendent (boss)
		"Transcendent",
	}

	// Calculate starting level ID for this module
	startID := (cfg.ModuleID-1)*levelsPerModule + 1

	common.Info("Generating module %d (levels %d-%d)...", cfg.ModuleID, startID, startID+levelsPerModule-1)
	common.Info("  Progression: Seedling → Sprout → Nurturing → Flourishing → Transcendent")

	// Generate all 21 levels
	for i := 0; i < levelsPerModule; i++ {
		levelID := startID + i
		isBoss := i == regularLevels
		var levelSeed int64
		if cfg.UseRandomSeed {
			levelSeed = time.Now().UnixNano() + int64(i)
		} else if cfg.BaseSeed != 0 {
			levelSeed = cfg.BaseSeed + int64(i)
		} else {
			levelSeed = cryptoSeedInt64() + int64(i)
		}
		rng := rand.New(rand.NewSource(levelSeed))
		var difficultyTier string
		if cfg.Difficulty != "" {
			difficultyTier = cfg.Difficulty
		} else {
			difficultyTier = difficultyProgression[i]
		}
		// Per-level retry logic
		var level model.Level
		var lastErr error
		maxRetries := 5
		for attempt := 1; attempt <= maxRetries; attempt++ {
			level, lastErr = generateSingleLevel(levelID, difficultyTier, levelSeed+int64(attempt)*7919, rng)
			if lastErr == nil {
				break
			}
			common.Verbose("[Module %d Level %d Attempt %d/%d] Generation failed: %v", cfg.ModuleID, levelID, attempt, maxRetries, lastErr)
		}
		if lastErr != nil {
			common.Error("Module %d Level %d failed after %d attempts: %v", cfg.ModuleID, levelID, maxRetries, lastErr)
			continue // Skip this level, continue batch
		}
		if isBoss {
			level.Name = fmt.Sprintf("Module %d - Transcendent", cfg.ModuleID)
			level.Complexity = "transcendent"
			level.Grace++
		}

		levelsDir, err := common.LevelsDir()
		if err != nil {
			common.Error("Failed to resolve levels directory for level %d in module %d: %v", levelID, cfg.ModuleID, err)
			continue
		}

		filePath := filepath.Join(levelsDir, fmt.Sprintf("level_%d.json", levelID))
		if err := common.WriteLevel(filePath, &level, cfg.Overwrite); err != nil {
			common.Error("Failed to write level %d: %v", levelID, err)
			continue
		}
		if isBoss {
			common.Verbose("Generated level %d (%s) - BOSS LEVEL", levelID, level.Name)
		} else {
			common.Verbose("Generated level %d (%s - %s)", levelID, level.Name, difficultyTier)
		}
	}

	common.Info("✓ Module %d complete (21 levels)", cfg.ModuleID)

	// Update modules.json registry
	return updateModuleRegistry(cfg.ModuleID, startID)
}

// updateModuleRegistry updates or creates the modules.json file with the new module.
func updateModuleRegistry(moduleID int, startID int) error {
	registryPath, err := common.ModulesFile()
	if err != nil {
		return fmt.Errorf("failed to resolve modules.json path: %w", err)
	}

	// Read existing registry or create new one
	var registry model.ModuleRegistry
	data, err := os.ReadFile(registryPath)
	if err == nil {
		if err := json.Unmarshal(data, &registry); err != nil {
			return fmt.Errorf("failed to parse existing modules.json: %w", err)
		}
	} else {
		// Initialize new registry
		registry = model.ModuleRegistry{
			Version:   "2.0",
			Tutorials: []int{1, 2, 3},
			Modules:   []model.Module{},
		}
	}

	// Build module entry
	moduleEntry := model.Module{
		ID:             moduleID,
		Name:           fmt.Sprintf("Module %d", moduleID),
		ThemeSeed:      getThemeSeed(moduleID),
		Levels:         []int{},
		ChallengeLevel: startID + 20, // 21st level is Transcendent boss
	}

	// Add the 20 regular levels
	for i := 0; i < 20; i++ {
		moduleEntry.Levels = append(moduleEntry.Levels, startID+i)
	}

	// Update or append module
	found := false
	for i, m := range registry.Modules {
		if m.ID == moduleID {
			registry.Modules[i] = moduleEntry
			found = true
			break
		}
	}
	if !found {
		registry.Modules = append(registry.Modules, moduleEntry)
	}

	// Write updated registry
	jsonData, err := json.MarshalIndent(registry, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal modules.json: %w", err)
	}

	if err := os.WriteFile(registryPath, jsonData, 0o644); err != nil {
		return fmt.Errorf("failed to write modules.json: %w", err)
	}

	common.Verbose("Updated modules.json for module %d", moduleID)
	return nil
}

// getThemeSeed returns a theme seed name for a module.
func getThemeSeed(moduleID int) string {
	themes := []string{"forest", "sunset", "ocean", "volcano", "lavender", "meadow", "twilight", "aurora"}
	if moduleID > 0 && moduleID <= len(themes) {
		return themes[moduleID-1]
	}
	return "default"
}

// generateSingleLevel creates a single level with the given parameters.
// It uses the tiling algorithm and validates solvability.
func generateSingleLevel(id int, difficulty string, seed int64, rng *rand.Rand) (model.Level, error) {
	const maxAttempts = 10000        // Increased from 1000 (attempts are fast ~0.8ms each)
	const maxGenerationTime = 60     // Circuit breaker: max 60 seconds per level
	const occupancyRelaxation = 0.05 // Relax by 5% when stuck
	const progressLogInterval = 100  // Log progress every N attempts

	startTime := time.Now()

	// Get difficulty-specific constraints
	spec, ok := config.DifficultySpecs[difficulty]
	if !ok {
		return model.Level{}, fmt.Errorf("unknown difficulty: %s", difficulty)
	}

	// Get grid size for this level
	gridSize := utils.GridSizeForLevel(id)

	// Get variety profile and generator config for this difficulty
	profile := utils.GetPresetProfile(difficulty)
	generatorCfg := utils.GetGeneratorConfigForDifficulty(difficulty)

	originalOccupancy := spec.MinGridOccupancy
	common.Verbose("Level %d: difficulty=%s, grid=%dx%d, target_occupancy=%.1f%%, max_attempts=%d",
		id, difficulty, gridSize[0], gridSize[1], originalOccupancy*100, maxAttempts)

	var level model.Level
	var attempts int
	tilingFailures := 0
	greedyFailures := 0
	bfsFailures := 0
	constraintFailures := 0

	for attempts = 0; attempts < maxAttempts; attempts++ {
		// Time-based circuit breaker
		elapsed := time.Since(startTime)
		if elapsed.Seconds() > maxGenerationTime {
			return model.Level{}, fmt.Errorf("generation timeout after %.1fs (%d attempts, tiling_fails=%d, greedy_fails=%d, bfs_fails=%d)",
				elapsed.Seconds(), attempts, tilingFailures, greedyFailures, bfsFailures)
		}

		// Progressive occupancy relaxation after many failures
		switch attempts {
		case 500:
			spec.MinGridOccupancy -= occupancyRelaxation
			common.Verbose("⚠️  Relaxing occupancy to %.1f%% after %d attempts (from %.1f%%)",
				spec.MinGridOccupancy*100, attempts, originalOccupancy*100)
		case 1500:
			spec.MinGridOccupancy -= occupancyRelaxation
			common.Verbose("⚠️  Further relaxing occupancy to %.1f%% after %d attempts",
				spec.MinGridOccupancy*100, attempts)
		case 3000:
			spec.MinGridOccupancy -= occupancyRelaxation
			common.Verbose("⚠️  Final occupancy relaxation to %.1f%% after %d attempts",
				spec.MinGridOccupancy*100, attempts)
		}

		// Log progress periodically
		if attempts > 0 && attempts%progressLogInterval == 0 {
			successful := float64(attempts - tilingFailures - greedyFailures - bfsFailures - constraintFailures)
			successRate := successful / float64(attempts) * 100
			common.Verbose("⏱️  Progress: %d/%d attempts (%.1fs, tiling_fails=%d, greedy_fails=%d, bfs_fails=%d, constraint_fails=%d, success_rate=%.1f%%)",
				attempts, maxAttempts, elapsed.Seconds(),
				tilingFailures, greedyFailures, bfsFailures, constraintFailures,
				successRate)
		}
		var vines []model.Vine
		var mask *model.Mask
		var err error

		// Create an attempt-local RNG to diversify retries (prevents repeating same trajectories)
		attemptRng := rand.New(rand.NewSource(seed + int64(attempts)*7919))

		// Determine which algorithm to use based on grid size and difficulty
		// ALWAYS use clearable-first to prevent circular blocking
		useClearableFirst := true

		if useClearableFirst {
			// Choose anchor ratio adaptively based on tiling failure history to avoid stalls
			anchorRatio := 0.3
			if tilingFailures > 30 {
				anchorRatio = 0.15 // use fewer anchors when we're struggling
			}
			if tilingFailures > 100 {
				// Last-resort: try standard tiling as a fallback to escape pathological cases
				common.Verbose("⚠️  Falling back to TileGridIntoVines after %d tiling failures", tilingFailures)
				vines, mask, err = strategies.TileGridIntoVines(gridSize, spec, profile, generatorCfg, attemptRng)
			} else {
				// Try clearable-first with adaptive anchor ratio
				vines, err = strategies.ClearableFirstPlacement(gridSize, spec, profile, generatorCfg, attemptRng.Int63(), anchorRatio, spec.MinGridOccupancy, true)
			}
			if err == nil {
				// Generate mask for empty cells (inline mask generation)
				occupied := make(map[string]bool)
				for _, v := range vines {
					for _, p := range v.OrderedPath {
						occupied[fmt.Sprintf("%d,%d", p.X, p.Y)] = true
					}
				}
				var emptyPoints []model.Point
				for y := 0; y < gridSize[1]; y++ {
					for x := 0; x < gridSize[0]; x++ {
						key := fmt.Sprintf("%d,%d", x, y)
						if !occupied[key] {
							emptyPoints = append(emptyPoints, model.Point{X: x, Y: y})
						}
					}
				}
				if len(emptyPoints) > 0 {
					mask = &model.Mask{Mode: "hide", Points: emptyPoints}
				}
			}
		} else if difficulty == "Nurturing" || difficulty == "Flourishing" || difficulty == "Transcendent" {
			// For higher difficulties on normal grids, use solver-aware placement
			vines, mask, err = strategies.SolverAwarePlacement(gridSize, spec, profile, generatorCfg, attemptRng)
		} else {
			// Use standard tiling for easier difficulties on normal grids
			vines, mask, err = strategies.TileGridIntoVines(gridSize, spec, profile, generatorCfg, attemptRng)
		}

		if err != nil {
			tilingFailures++
			if attempts < 10 || (attempts > 0 && attempts%100 == 0) {
				common.Verbose("Attempt %d: Tiling failed - %v", attempts+1, err)
			}
			continue
		}

		// Assign color indices from palette
		assignColorIndices(vines, len(config.ColorPalette), rng)

		// Build level
		level = model.Level{
			ID:          id,
			Name:        fmt.Sprintf("Level %d", id),
			Difficulty:  difficulty,
			GridSize:    gridSize,
			Vines:       vines,
			MaxMoves:    0, // Will calculate below
			MinMoves:    0, // Will calculate below
			Complexity:  common.ComplexityForDifficulty(difficulty),
			Grace:       utils.GraceForDifficulty(difficulty),
			ColorScheme: config.ColorPalette, // Use standard palette
			Mask:        mask,

			// Generation metadata
			GenerationSeed:     seed,
			GenerationAttempts: attempts + 1,
		}

		modelLevel := convertToModelLevel(level)
		if constraintErrs := validator.ValidateDesignConstraints(modelLevel); len(constraintErrs) > 0 {
			constraintFailures++
			if attempts < 10 || (attempts > 0 && attempts%progressLogInterval == 0) {
				common.Verbose("Attempt %d: Design constraints failed (%d issues) - %s",
					attempts+1, len(constraintErrs), constraintErrs[0].Error())
			}
			continue
		}

		// Validate solvability using the solver
		solver := common.NewSolver(&level)
		if !solver.IsSolvableGreedy() {
			greedyFailures++
			if attempts < 10 || (attempts > 0 && attempts%100 == 0) {
				common.Verbose("Attempt %d: Level not solvable (greedy check)", attempts+1)
			}
			continue
		}

		// For higher difficulties, also check with BFS
		if difficulty == "Nurturing" || difficulty == "Flourishing" || difficulty == "Transcendent" {
			if !solver.IsSolvableBFS() {
				bfsFailures++
				if attempts < 10 || (attempts > 0 && attempts%100 == 0) {
					common.Verbose("Attempt %d: Level not solvable (BFS check)", attempts+1)
				}
				continue
			}
		}

		// Calculate min/max moves based on vine count
		vineCount := len(vines)
		level.MinMoves = vineCount
		level.MaxMoves = int(float64(vineCount) * 1.5)
		if level.MaxMoves < 5 {
			level.MaxMoves = 5
		}

		// Record generation time
		elapsed = time.Since(startTime)
		level.GenerationElapsedMS = elapsed.Milliseconds()

		// Calculate a quality score based on vine count and complexity
		level.GenerationScore = calculateLevelScore(&level, attempts+1)

		common.Verbose("✓ Level %d generated successfully after %d attempts (%.2fs, score: %.2f, tiling_fails=%d, greedy_fails=%d, bfs_fails=%d)",
			id, attempts+1, elapsed.Seconds(), level.GenerationScore, tilingFailures, greedyFailures, bfsFailures)
		return level, nil
	}

	elapsed := time.Since(startTime)
	return model.Level{}, fmt.Errorf("failed to generate solvable level after %d attempts in %.1fs (tiling_fails=%d, greedy_fails=%d, bfs_fails=%d)",
		attempts, elapsed.Seconds(), tilingFailures, greedyFailures, bfsFailures)
}

// calculateLevelScore computes a quality score for the generated level.
// Higher scores indicate better levels (good vine distribution, appropriate complexity).
func calculateLevelScore(level *model.Level, attempts int) float64 {
	score := 100.0

	// Penalize for too many generation attempts
	if attempts > 100 {
		score -= float64(attempts-100) * 0.1
	}

	// Reward for good vine count relative to grid size
	totalCells := level.GridSize[0] * level.GridSize[1]
	occupiedCells := 0
	for _, v := range level.Vines {
		occupiedCells += len(v.OrderedPath)
	}
	occupancy := float64(occupiedCells) / float64(totalCells)

	if occupancy >= 0.85 && occupancy <= 0.95 {
		score += 10.0 // Good occupancy
	} else if occupancy < 0.7 {
		score -= 20.0 // Too sparse
	}

	// Reward for variety in vine lengths
	if len(level.Vines) > 2 {
		minLen := len(level.Vines[0].OrderedPath)
		maxLen := minLen
		for _, v := range level.Vines {
			l := len(v.OrderedPath)
			if l < minLen {
				minLen = l
			}
			if l > maxLen {
				maxLen = l
			}
		}
		lengthVariety := float64(maxLen - minLen)
		score += lengthVariety * 2.0
	}

	return score
}

// assignColorIndices assigns random color indices to vines from the palette.
func assignColorIndices(vines []model.Vine, paletteSize int, rng *rand.Rand) {
	for i := range vines {
		vines[i].ColorIndex = rng.Intn(paletteSize)
	}
}

func convertToModelLevel(level model.Level) model.Level {
	return model.Level{
		ID:          level.ID,
		Name:        level.Name,
		Difficulty:  level.Difficulty,
		Complexity:  level.Complexity,
		GridSize:    append([]int(nil), level.GridSize...),
		Mask:        convertMask(level.Mask),
		Vines:       convertVines(level.Vines),
		MaxMoves:    level.MaxMoves,
		MinMoves:    level.MinMoves,
		Grace:       level.Grace,
		ColorScheme: append([]string(nil), level.ColorScheme...),
	}
}

func convertMask(mask *model.Mask) *model.Mask {
	if mask == nil {
		return nil
	}
	points := make([]model.Point, len(mask.Points))
	for i, p := range mask.Points {
		points[i] = model.Point{X: p.X, Y: p.Y}
	}
	return &model.Mask{Mode: mask.Mode, Points: points}
}

func convertVines(vines []model.Vine) []model.Vine {
	out := make([]model.Vine, len(vines))
	for i, v := range vines {
		out[i] = model.Vine{
			ID:            v.ID,
			HeadDirection: v.HeadDirection,
			OrderedPath:   convertPoints(v.OrderedPath),
			ColorIndex:    v.ColorIndex,
		}
	}
	return out
}

func convertPoints(points []model.Point) []model.Point {
	out := make([]model.Point, len(points))
	for i, p := range points {
		out[i] = model.Point{X: p.X, Y: p.Y}
	}
	return out
}
