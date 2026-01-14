package generator

import (
	"encoding/json"
	"fmt"
	"math/rand"
	"os"
	"path/filepath"
	"time"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
)

const (
	AssetsDir   = "../../assets"
	LevelsDir   = AssetsDir + "/levels"
	DataDir     = AssetsDir + "/data"
	ModulesFile = DataDir + "/modules.json"
)

// GenerationConfig holds configuration for level generation
type GenerationConfig struct {
	Count         int
	BaseSeed      int64
	UseRandomSeed bool
	ModuleID      int
	Difficulty    string
	WorkingDir    string
}

// Clean removes generated level and module files used by the level builder.
func Clean() error {
	files, err := filepath.Glob(filepath.Join(LevelsDir, "level_*.json"))
	if err != nil {
		return err
	}
	for _, f := range files {
		if err := os.Remove(f); err != nil && !os.IsNotExist(err) {
			return fmt.Errorf("failed to remove %s: %w", f, err)
		}
	}
	if err := os.Remove(ModulesFile); err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("failed to remove %s: %w", ModulesFile, err)
	}
	return nil
}

// Generate creates count levels with the given configuration.
// This is the main entry point called from the generate command.
func Generate(count int, baseSeed int64, useRandomSeed bool, moduleID int, difficulty string) error {
	cwd, _ := os.Getwd()
	common.Verbose("Generating %d levels (CWD: %s)...", count, cwd)

	// Ensure output directories exist
	if err := os.MkdirAll(LevelsDir, 0755); err != nil {
		return err
	}
	if err := os.MkdirAll(DataDir, 0755); err != nil {
		return err
	}

	cfg := GenerationConfig{
		Count:         count,
		BaseSeed:      baseSeed,
		UseRandomSeed: useRandomSeed,
		ModuleID:      moduleID,
		Difficulty:    difficulty,
		WorkingDir:    cwd,
	}

	// If module ID is specified, generate entire module
	if moduleID > 0 {
		return generateModule(cfg)
	}

	// Otherwise, generate individual levels
	return generateLevels(cfg)
}

// generateLevels generates a series of individual levels.
func generateLevels(cfg GenerationConfig) error {
	// Determine the starting level ID
	startID := 1
	existingLevels, err := common.ReadLevelsFromDir(LevelsDir)
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

		// Determine seed for this level
		var levelSeed int64
		if cfg.UseRandomSeed {
			levelSeed = time.Now().UnixNano() + int64(i)
		} else if cfg.BaseSeed != 0 {
			levelSeed = cfg.BaseSeed + int64(i)
		} else {
			levelSeed = int64(levelID) * 31337 // Deterministic default
		}

		rng := rand.New(rand.NewSource(levelSeed))

		// Determine difficulty tier
		var difficultyTier string
		if cfg.Difficulty != "" {
			difficultyTier = cfg.Difficulty
		} else {
			difficultyTier = common.DifficultyForLevel(levelID)
		}

		// Generate level with retries
		level, err := generateSingleLevel(levelID, difficultyTier, levelSeed, rng)
		if err != nil {
			return fmt.Errorf("failed to generate level %d: %w", levelID, err)
		}

		// Write level to disk
		filePath := filepath.Join(LevelsDir, fmt.Sprintf("level_%d.json", levelID))
		if err := common.WriteLevel(filePath, &level, false); err != nil {
			return fmt.Errorf("failed to write level %d: %w", levelID, err)
		}

		if (i+1)%10 == 0 || (i+1) == cfg.Count {
			common.Info("Generated %d/%d levels...", i+1, cfg.Count)
		}
	}

	common.Info("Successfully generated %d levels", cfg.Count)
	return nil
}

// generateModule generates a complete module (9 regular + 1 challenge level).
func generateModule(cfg GenerationConfig) error {
	const levelsPerModule = 10
	const regularLevels = 9

	// Calculate starting level ID for this module
	startID := (cfg.ModuleID-1)*levelsPerModule + 1

	common.Info("Generating module %d (levels %d-%d)...", cfg.ModuleID, startID, startID+levelsPerModule-1)

	// Generate 9 regular levels + 1 challenge level
	for i := 0; i < levelsPerModule; i++ {
		levelID := startID + i
		isChallenge := i == regularLevels

		// Determine seed
		var levelSeed int64
		if cfg.UseRandomSeed {
			levelSeed = time.Now().UnixNano() + int64(i)
		} else if cfg.BaseSeed != 0 {
			levelSeed = cfg.BaseSeed + int64(i)
		} else {
			levelSeed = int64(levelID) * 31337
		}

		rng := rand.New(rand.NewSource(levelSeed))

		// Determine difficulty tier
		var difficultyTier string
		if cfg.Difficulty != "" {
			difficultyTier = cfg.Difficulty
		} else {
			difficultyTier = common.DifficultyForLevel(levelID)
		}

		// Generate level
		level, err := generateSingleLevel(levelID, difficultyTier, levelSeed, rng)
		if err != nil {
			return fmt.Errorf("failed to generate level %d: %w", levelID, err)
		}

		// Mark as challenge if applicable
		if isChallenge {
			level.Name = fmt.Sprintf("Challenge %d", cfg.ModuleID)
			level.Grace++ // Extra grace for challenge levels
		}

		// Write level to disk
		filePath := filepath.Join(LevelsDir, fmt.Sprintf("level_%d.json", levelID))
		if err := common.WriteLevel(filePath, &level, false); err != nil {
			return fmt.Errorf("failed to write level %d: %w", levelID, err)
		}

		common.Verbose("Generated level %d (%s)", levelID, level.Name)
	}

	common.Info("✓ Module %d complete", cfg.ModuleID)

	// Update modules.json registry
	return updateModuleRegistry(cfg.ModuleID, startID)
}

// updateModuleRegistry updates or creates the modules.json file with the new module.
func updateModuleRegistry(moduleID int, startID int) error {
	registryPath := ModulesFile

	// Read existing registry or create new one
	var registry common.ModuleRegistry
	data, err := os.ReadFile(registryPath)
	if err == nil {
		if err := json.Unmarshal(data, &registry); err != nil {
			return fmt.Errorf("failed to parse existing modules.json: %w", err)
		}
	} else {
		// Initialize new registry
		registry = common.ModuleRegistry{
			Version:   "2.0",
			Tutorials: []int{1, 2, 3},
			Modules:   []common.Module{},
		}
	}

	// Build module entry
	moduleEntry := common.Module{
		ID:             moduleID,
		Name:           fmt.Sprintf("Module %d", moduleID),
		ThemeSeed:      getThemeSeed(moduleID),
		Levels:         []int{},
		ChallengeLevel: startID + 9, // 10th level is challenge
	}

	// Add the 9 regular levels
	for i := 0; i < 9; i++ {
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

	if err := os.WriteFile(registryPath, jsonData, 0644); err != nil {
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
func generateSingleLevel(id int, difficulty string, seed int64, rng *rand.Rand) (common.Level, error) {
	const maxAttempts = 10000        // Increased from 1000 (attempts are fast ~0.8ms each)
	const maxGenerationTime = 60     // Circuit breaker: max 60 seconds per level
	const occupancyRelaxation = 0.05 // Relax by 5% when stuck
	const progressLogInterval = 100  // Log progress every N attempts

	startTime := time.Now()

	// Get difficulty-specific constraints
	spec, ok := common.DifficultySpecs[difficulty]
	if !ok {
		return common.Level{}, fmt.Errorf("unknown difficulty: %s", difficulty)
	}

	// Get grid size for this level
	gridSize := common.GridSizeForLevel(id)

	// Get variety profile and generator config for this difficulty
	profile := common.GetPresetProfile(difficulty)
	generatorCfg := common.GetGeneratorConfigForDifficulty(difficulty)

	originalOccupancy := spec.MinGridOccupancy
	common.Verbose("Level %d: difficulty=%s, grid=%dx%d, target_occupancy=%.1f%%, max_attempts=%d",
		id, difficulty, gridSize[0], gridSize[1], originalOccupancy*100, maxAttempts)

	var level common.Level
	var attempts int
	tilingFailures := 0
	greedyFailures := 0
	bfsFailures := 0

	for attempts = 0; attempts < maxAttempts; attempts++ {
		// Time-based circuit breaker
		elapsed := time.Since(startTime)
		if elapsed.Seconds() > maxGenerationTime {
			return common.Level{}, fmt.Errorf("generation timeout after %.1fs (%d attempts, tiling_fails=%d, greedy_fails=%d, bfs_fails=%d)",
				elapsed.Seconds(), attempts, tilingFailures, greedyFailures, bfsFailures)
		}

		// Progressive occupancy relaxation after many failures
		if attempts == 500 {
			spec.MinGridOccupancy -= occupancyRelaxation
			common.Verbose("⚠️  Relaxing occupancy to %.1f%% after %d attempts (from %.1f%%)",
				spec.MinGridOccupancy*100, attempts, originalOccupancy*100)
		} else if attempts == 1500 {
			spec.MinGridOccupancy -= occupancyRelaxation
			common.Verbose("⚠️  Further relaxing occupancy to %.1f%% after %d attempts",
				spec.MinGridOccupancy*100, attempts)
		} else if attempts == 3000 {
			spec.MinGridOccupancy -= occupancyRelaxation
			common.Verbose("⚠️  Final occupancy relaxation to %.1f%% after %d attempts",
				spec.MinGridOccupancy*100, attempts)
		}

		// Log progress periodically
		if attempts > 0 && attempts%progressLogInterval == 0 {
			common.Verbose("⏱️  Progress: %d/%d attempts (%.1fs, tiling_fails=%d, greedy_fails=%d, bfs_fails=%d, success_rate=%.1f%%)",
				attempts, maxAttempts, elapsed.Seconds(),
				tilingFailures, greedyFailures, bfsFailures,
				float64(attempts-tilingFailures-greedyFailures-bfsFailures)/float64(attempts)*100)
		}
		var vines []common.Vine
		var mask *common.Mask
		var err error

		// Determine which algorithm to use based on grid size and difficulty
		gridArea := gridSize[0] * gridSize[1]
		useClearableFirst := gridArea > 120 // Use clearable-first for grids larger than ~10x12

		if useClearableFirst {
			// For large grids, use clearable-first placement with incremental greedy checks
			vines, err = ClearableFirstPlacement(gridSize, spec, profile, generatorCfg, rng.Int63(), 0.3, true)
			if err == nil {
				// Generate mask for empty cells (inline mask generation)
				occupied := make(map[string]bool)
				for _, v := range vines {
					for _, p := range v.OrderedPath {
						occupied[fmt.Sprintf("%d,%d", p.X, p.Y)] = true
					}
				}
				var emptyPoints []common.Point
				for y := 0; y < gridSize[1]; y++ {
					for x := 0; x < gridSize[0]; x++ {
						key := fmt.Sprintf("%d,%d", x, y)
						if !occupied[key] {
							emptyPoints = append(emptyPoints, common.Point{X: x, Y: y})
						}
					}
				}
				if len(emptyPoints) > 0 {
					mask = &common.Mask{Mode: "hide", Points: emptyPoints}
				}
			}
		} else if difficulty == "Nurturing" || difficulty == "Flourishing" || difficulty == "Transcendent" {
			// For higher difficulties on normal grids, use solver-aware placement
			vines, mask, err = SolverAwarePlacement(gridSize, spec, profile, generatorCfg, rng)
		} else {
			// Use standard tiling for easier difficulties on normal grids
			vines, mask, err = TileGridIntoVines(gridSize, spec, profile, generatorCfg, rng)
		}

		if err != nil {
			tilingFailures++
			if attempts < 10 || (attempts > 0 && attempts%100 == 0) {
				common.Verbose("Attempt %d: Tiling failed - %v", attempts+1, err)
			}
			continue
		}

		// Assign color indices from palette
		assignColorIndices(vines, len(common.ColorPalette), rng)

		// Build level
		level = common.Level{
			ID:          id,
			Name:        fmt.Sprintf("Level %d", id),
			Difficulty:  difficulty,
			GridSize:    gridSize,
			Vines:       vines,
			MaxMoves:    0, // Will calculate below
			MinMoves:    0, // Will calculate below
			Complexity:  common.ComplexityForDifficulty(difficulty),
			Grace:       common.GraceForDifficulty(difficulty),
			ColorScheme: common.ColorPalette, // Use standard palette
			Mask:        mask,

			// Generation metadata
			GenerationSeed:     seed,
			GenerationAttempts: attempts + 1,
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
	return common.Level{}, fmt.Errorf("failed to generate solvable level after %d attempts in %.1fs (tiling_fails=%d, greedy_fails=%d, bfs_fails=%d)",
		attempts, elapsed.Seconds(), tilingFailures, greedyFailures, bfsFailures)
}

// calculateLevelScore computes a quality score for the generated level.
// Higher scores indicate better levels (good vine distribution, appropriate complexity).
func calculateLevelScore(level *common.Level, attempts int) float64 {
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
func assignColorIndices(vines []common.Vine, paletteSize int, rng *rand.Rand) {
	for i := range vines {
		vines[i].ColorIndex = rng.Intn(paletteSize)
	}
}
